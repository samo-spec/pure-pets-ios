//
//  ZXQRScanViewController.m
//  XXXX
//
//  Created by JuanFelix on 2016/12/5.
//  Copyright © 2016年 screson. All rights reserved.
//

#import "ZXQRScanViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "PPPermissionHelper.h"

#define ZX_BOUNDS_WIDTH     ([[UIScreen mainScreen] bounds].size.width)
#define ZX_BOUNDS_HEIGHT    ([[UIScreen mainScreen] bounds].size.height)
#define ZX_IOS8_OR_LATER    ([[[UIDevice currentDevice] systemVersion] compare:@"8.0" options:NSNumericSearch] != NSOrderedAscending)

@interface ZXQRScanViewController ()<AVCaptureMetadataOutputObjectsDelegate>{
    BOOL  checking;
}
@property (weak, nonatomic) IBOutlet UIButton *btnBack;

@property (weak, nonatomic) IBOutlet UIView * contentView;//Boarding the image
@property (weak, nonatomic) IBOutlet UIView * scanFrame;  //Scan the area

@property (strong, nonatomic) UIImageView * animationImage;
@property (nonatomic, strong) AVCaptureSession *session;

@end

@implementation ZXQRScanViewController

+ (ZXQRScanViewController *)startScanInViewController:(UIViewController *)vc asPush:(BOOL)push autoDismiss:(BOOL)autoDismiss callBack:(ZXCallBack)callBack{
    ZXQRScanViewController * scanVC = [[ZXQRScanViewController alloc] init];
    scanVC.zxCallBack = callBack;
    scanVC.autoDismiss = autoDismiss;
    scanVC.view.layer.cornerRadius = 25;
    scanVC.view.clipsToBounds = YES;
    if (push) {
        if ([vc isKindOfClass:[UINavigationController class]]) {
            [(UINavigationController *)vc pushViewController:scanVC animated:true];
        }else if (vc.navigationController){
            [vc.navigationController pushViewController:scanVC animated:true];
        }else{
           // [vc presentViewController:scanVC animated:true completion:nil];
            [vc presentViewController:scanVC
                                 inSize:CGSizeMake(vc.view.frame.size.width , 600)
                              direction:PVCDirectionBottom
                             completion:^{ }];
        }
    }else{
       // [vc presentViewController:scanVC animated:true completion:nil];
        [vc presentViewController:scanVC
                             inSize:CGSizeMake(vc.view.frame.size.width , 600)
                          direction:PVCDirectionBottom
                         completion:^{ }];
    }
    return scanVC;
}

- (instancetype)init{
    if (self = [super init]) {
        [self setHidesBottomBarWhenPushed:true];
    }
    return self;
}

- (void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:true animated:true];
}

- (void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    [self checkEnvironmentAndRun];
}


- (void)viewWillDisappear:(BOOL)animated{
    [super viewWillDisappear:animated];
    [self.navigationController setNavigationBarHidden:false animated:true];
}


- (void)viewDidDisappear:(BOOL)animated{
    [super viewDidDisappear:animated];
    [self stopScan];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    checking = false;
    [self.scanFrame setBackgroundColor:[UIColor clearColor]];
    //
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(s_enterBackground) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(s_enterForeground) name:UIApplicationWillEnterForegroundNotification object:nil];
}

- (void)s_enterBackground{
    _animationImage.layer.timeOffset = CACurrentMediaTime();
}

- (void)s_enterForeground{
    [self resumeAnimation];
}


//MARK: - Camera environment detection
- (void)checkEnvironmentAndRun{
    __weak typeof(self) weakSelf = self;
    [PPPermissionHelper requestCameraPermissionFromViewController:self
                                                       completion:^(BOOL granted) {
        if (granted) {
            [weakSelf beginScanning];
        }
    }];
}

- (void)stopScan{
    if (_session && [_session isRunning]) {
        [_session stopRunning];
    }
    [_animationImage.layer removeAllAnimations];
}

- (void)restartScan{
    if (_session) {
        if ([_session isRunning]) {
            return;
        }
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            [_session startRunning];
        });
        [self resumeAnimation];
    }
}

//MARK: - Empty mask layer
- (void)addMaskLayer{
    CALayer * maskLayer = [[CALayer alloc] init];
    maskLayer.frame = [UIScreen mainScreen].bounds;
    maskLayer.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.6].CGColor;
    CAShapeLayer * empty = [CAShapeLayer layer];
    UIBezierPath * path = [UIBezierPath bezierPathWithRect:maskLayer.frame];
    CGRect frame = self.scanFrame.frame;
    [path appendPath:[[UIBezierPath bezierPathWithRoundedRect:CGRectMake(frame.origin.x, frame.origin.y, frame.size.width, frame.size.height) cornerRadius:0] bezierPathByReversingPath]];
    empty.path = path.CGPath;
    maskLayer.mask = empty;
    
    [self.contentView.layer insertSublayer:maskLayer below:_btnBack.layer];
    
    _animationImage = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"scan_net"]];
}

- (void)beginScanning
{
    if (!_session) {
        //Get camera equipment
        AVCaptureDevice * device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        if (!device) {
            NSLog(@"❌ ZXQRScan: No video capture device available");
            [self showAAlertWithTitle:@"Tip" message:@"Camera Not Available" buttonTexts:@[@"knew"] buttonAction:nil];
            return;
        }
        AVCaptureDeviceInput * input = [AVCaptureDeviceInput deviceInputWithDevice:device error:nil];//Input Stream
        if (!input) {
            [self showAAlertWithTitle:@"Tip" message:@"Camera Not Available" buttonTexts:@[@"knew"] buttonAction:nil];
            return;
        }
        AVCaptureMetadataOutput * output = [[AVCaptureMetadataOutput alloc]init];//Output Stream
        //Set the proxy to refresh in the main thread
        [output setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];
        //Set the valid scanning area
         CGRect scanCrop=[self getScanCrop:self.scanFrame.frame readerViewBounds:self.contentView.bounds];
        //Set the scan range CGRectMake(Y,X,H,W), 1 represents the maximum value. The upper right corner reference
        output.rectOfInterest = scanCrop;
        //Initialize the link object
        _session = [[AVCaptureSession alloc]init];
        //High quality collection rate
        [_session setSessionPreset:AVCaptureSessionPresetHigh];
        [_session addInput:input];
        [_session addOutput:output];
        //Set the encoding format supported by scanning code (set the barcode and QR code compatible as follows,)
        output.metadataObjectTypes=@[AVMetadataObjectTypeQRCode,AVMetadataObjectTypeCode128Code,AVMetadataObjectTypeEAN8Code,AVMetadataObjectTypeEAN13Code,AVMetadataObjectTypeCode39Code,AVMetadataObjectTypeCode93Code,AVMetadataObjectTypeUPCECode,AVMetadataObjectTypeCode39Mod43Code,AVMetadataObjectTypePDF417Code,AVMetadataObjectTypeAztecCode,AVMetadataObjectTypeITF14Code,AVMetadataObjectTypeDataMatrixCode];
        
        AVCaptureVideoPreviewLayer * layer = [AVCaptureVideoPreviewLayer layerWithSession:_session];
        layer.videoGravity=AVLayerVideoGravityResizeAspectFill;
        layer.frame= CGRectMake(0, 0, ZX_BOUNDS_WIDTH, ZX_BOUNDS_HEIGHT);
        [self.contentView.layer insertSublayer:layer atIndex:0];
        [self addMaskLayer];//Add a leaky layer mask
    }
    [self restartScan];
}

//MARK: - Recover animation
- (void)resumeAnimation
{
    CAAnimation *anim = [_animationImage.layer animationForKey:@"translationAnimation"];
    if(anim){
        CFTimeInterval pauseTime = _animationImage.layer.timeOffset;
        CFTimeInterval beginTime = CACurrentMediaTime() - pauseTime;
        [_animationImage.layer setTimeOffset:0.0];
        [_animationImage.layer setBeginTime:beginTime];
        [_animationImage.layer setSpeed:1.0];
    }else{
        CGFloat scanNetImageViewH = self.scanFrame.frame.size.height;
        CGFloat scanNetImageViewW = self.scanFrame.frame.size.width;
        _animationImage.frame = CGRectMake(0, -scanNetImageViewH, scanNetImageViewW, scanNetImageViewH);
        CABasicAnimation *scanNetAnimation = [CABasicAnimation animation];
        scanNetAnimation.keyPath = @"transform.translation.y";
        scanNetAnimation.byValue = @(scanNetImageViewW);
        scanNetAnimation.duration = 1.0;
        scanNetAnimation.repeatCount = MAXFLOAT;
        [_animationImage.layer addAnimation:scanNetAnimation forKey:@"translationAnimation"];
        [self.scanFrame addSubview:_animationImage];
    }
}

//MARK: - Get the proportional relationship of the scan area
- (CGRect)getScanCrop:(CGRect)rect readerViewBounds:(CGRect)readerViewBounds
{
    CGFloat x,y,width,height;
    x = rect.origin.y / CGRectGetHeight(readerViewBounds);
    y = (CGRectGetWidth(readerViewBounds) - CGRectGetWidth(rect)) / 2 / CGRectGetWidth(readerViewBounds);
    width  = CGRectGetHeight(rect)/CGRectGetHeight(readerViewBounds);
    height = CGRectGetWidth(rect)/CGRectGetWidth(readerViewBounds);
    return CGRectMake(x, y, width, height);//(Y,X,W,H)
}

//MARK: - AVCaptureMetadataOutputObjects Delegate
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection{
    if (checking) {
        return;
    }
    checking = true;
    if (metadataObjects.count > 0) {
        
        AVMetadataMachineReadableCodeObject * metadataObject = [metadataObjects objectAtIndex:0];
        NSString * result = metadataObject.stringValue;
        if (_zxCallBack) {
            _zxCallBack(result);
        }
        if (_autoDismiss) {
            [self stopScan];
            [self dismiss];
        }else{
            checking = false;
        }
    }else{
        checking = false;
    }
}

//MARK: - AlertUtils
- (void)showAAlertWithTitle:(NSString *)title
                    message:(NSString *)msg
                buttonTexts:(NSArray *)arrTexts
               buttonAction:(void (^)(int buttonIndex))buttonAction{
    if (arrTexts && arrTexts.count) {
        UIAlertController * alert = [UIAlertController alertControllerWithTitle:title ? title : @"hint" message:msg preferredStyle:UIAlertControllerStyleAlert];
        int index = 0;
        for (NSString * strText in arrTexts) {
            [alert addAction:[UIAlertAction actionWithTitle:strText ? strText :@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                if (buttonAction) {
                    buttonAction(index);
                }
            }]];
            index++;
        }
        [self presentViewController:alert animated:true completion:nil];
    }
}

- (IBAction)backAction:(id)sender {
    if (self.navigationController) {
        [self.navigationController popViewControllerAnimated:true];
    }else{
        [self dismissViewControllerAnimated:true completion:nil];
    }
}

- (void)dismiss{
    [self backAction:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
