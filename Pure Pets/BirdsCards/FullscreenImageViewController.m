//  FullscreenImageViewController.m

#import "FullscreenImageViewController.h"
#import <UIKit/UIKit.h>

@interface FullscreenImageViewController () <UIScrollViewDelegate,UIPrintInteractionControllerDelegate>
@property (nonatomic, strong) UIView *ContainerView;
@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) UIButton *printButton;
@property (nonatomic, strong) UIButton *close;
@property (nonatomic, strong) UILabel *titleLabel;
@end

@implementation FullscreenImageViewController

- (instancetype)initWithImage:(UIImage *)image {
    self = [super init];
    if (self) {
        _image = image;
    }
    return self;
}

-(void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    self.ContainerView.hx_y = 0;
    self.ContainerView.hx_h = self.view.frame.size.height - 50;
    self.imageView.hx_y =  90;
    
    self.imageView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.imageView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor].active = YES;
    [self.imageView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor].active = YES;
    [self.imageView.widthAnchor constraintEqualToConstant:300].active = YES;
    [self.imageView.heightAnchor constraintEqualToConstant:300].active = YES;
    
    
    [self.close.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16].active = YES;
    [self.close.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:16].active = YES;
    [self.close.widthAnchor constraintEqualToConstant:50].active = YES;
    [self.close.heightAnchor constraintEqualToConstant:50].active = YES;
    
    [self.printButton.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16].active = YES;
    [self.printButton.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:16].active = YES;
    [self.printButton.widthAnchor constraintEqualToConstant:50].active = YES;
    [self.printButton.heightAnchor constraintEqualToConstant:50].active = YES;
    [self.view bringSubviewToFront:self.printButton];
    [self.view bringSubviewToFront:self.close];
    [self.view sendSubviewToBack:self.ContainerView];
    
}
- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = PPIOS26() ? [UIColor clearColor] : AppBackgroundClr;
    
    // Setup ScrollView for swipe-down dismissal
    self.ContainerView = [[UIView alloc] init];
    self.ContainerView.backgroundColor = [UIColor clearColor];
    self.ContainerView.hx_h = self.view.frame.size.height ;
    self.ContainerView.hx_w = self.view.frame.size.width - 0;
    self.ContainerView.hx_x = 0;
    self.ContainerView.hx_y = 0;
    self.ContainerView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin;
    self.ContainerView.layer.cornerRadius = 20;
    self.ContainerView.clipsToBounds = YES;
    [self.view addSubview:self.ContainerView];
    
    
    self.imageView = [[UIImageView alloc] init];
    self.imageView.contentMode = UIViewContentModeScaleAspectFill;
    
    
    // self.imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.imageView.image = self.image;
    [self.ContainerView addSubview:self.imageView];
    
    // Print button setup (as before)
    self.printButton = [self pp_ButtonWithSystemName:@"printer.filled.and.paper" action:@selector(printImage:)];
    self.printButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.ContainerView addSubview:self.printButton];
    
    
    
    UITapGestureRecognizer *tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
    [self.view addGestureRecognizer:tapRecognizer];
    
    
    self.close = [self pp_ButtonWithSystemName:@"multiply" action:@selector(close:)];
    self.close.translatesAutoresizingMaskIntoConstraints = NO;
    [self.ContainerView addSubview:self.close];
    
    _titleLabel = [[UILabel alloc] init];
    _titleLabel.backgroundColor = [UIColor colorWithHexString:@"#F4F4F4"];
    _titleLabel.text = @"تم إنشاء باركود للقفص بنجاح";
    _titleLabel.font = [GM boldFontWithSize:16];
    _titleLabel.textAlignment = NSTextAlignmentCenter;
    _titleLabel.textColor = GM.appPrimaryColor;
    [self.ContainerView addSubview:_titleLabel];
}

- (void)close:(UIButton *)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}


#pragma mark - Other Methods (Tap, Print, etc.)
- (void)handleTap:(UITapGestureRecognizer *)recognizer {
    [self dismissViewControllerAnimated:YES completion:nil];
}


- (void)printImage:(UIButton *)sender {
    UIPrintInteractionController *pic = [UIPrintInteractionController sharedPrintController];
    if (pic && [UIPrintInteractionController canPrintData:UIImagePNGRepresentation(self.image)]) {
        pic.delegate = self;

        UIPrintInfo *printInfo = [UIPrintInfo printInfo];
        printInfo.outputType = UIPrintInfoOutputGeneral;
        printInfo.jobName = [NSString stringWithFormat:@"Image Print"];
        pic.printInfo = printInfo;
        pic.showsPageRange = NO;

        pic.printingItem = self.image;

        [pic presentAnimated:YES completionHandler:^(UIPrintInteractionController *printInteractionController, BOOL completed, NSError *error) {
            if (!completed && error) {
                NSLog(@"Printing failed: %@", error);

                UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Print Error" message:[NSString stringWithFormat:@"Failed to print: %@", error.localizedDescription] preferredStyle:UIAlertControllerStyleAlert];

                [alertController addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];

                [self presentViewController:alertController animated:YES completion:nil];

            }
        }];
    } else {
        NSLog(@"Printing is not available.");

        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Print Error" message:@"Printing is not available on this device." preferredStyle:UIAlertControllerStyleAlert];

        [alertController addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];

        [self presentViewController:alertController animated:YES completion:nil];
    }
}

@end
