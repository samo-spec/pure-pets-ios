
#import "PPSalesPDFGenerator.h"
#import "BuyerModel.h"
#import "CardModel.h"

@implementation PPSalesPDFGenerator
+(NSURL * _Nullable)generateSalesBillPDFWithBuyer:(BuyerModel *)buyer card:(CardModel *)card autoShow:(BOOL)autoShow
{
    if (!buyer || !card) {
        NSLog(@"❌ PPSalesPDFGenerator: nil buyer or card, aborting");
        return nil;
    }
    NSString *fileName =
    [NSString stringWithFormat:@"PurePets_Sales_%@.pdf",
     buyer.ID ?: kLang(@"SalesBillFileFallback")];

    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:fileName];
    NSURL *url = [NSURL fileURLWithPath:path];

    CGRect pageRect = CGRectMake(0, 0, 595, 842); // A4

    UIGraphicsBeginPDFContextToFile(path, CGRectZero, nil);
    UIGraphicsBeginPDFPageWithInfo(pageRect, nil);

    CGContextRef ctx = UIGraphicsGetCurrentContext();
    if (!ctx) {
        UIGraphicsEndPDFContext();
        return nil;
    }

    BOOL isRTL =Language.isRTL;

    CGFloat pagePadding = 40;
    __block CGFloat y = 40;

    // =========================
    // Fonts
    // =========================
    
    UIFont *titleFont = [GM boldFontWithSize: 26] ?: [UIFont boldSystemFontOfSize:22];
    UIFont *sectionFont = [GM boldFontWithSize:20] ?: [UIFont boldSystemFontOfSize:18];
    UIFont *labelFont = [GM MidFontWithSize:16] ?: [UIFont systemFontOfSize:16];
    UIFont *valueFont = [GM MidFontWithSize:16] ?: [UIFont boldSystemFontOfSize:16];
    UIFont *amountFont = [GM boldFontWithSize:20] ?: [UIFont boldSystemFontOfSize:20];

    // =========================
    // Logo (Centered)
    // =========================
    
    UIImage *logo = [UIImage imageNamed:@"tintLogo"];
    if (logo) {
        CGFloat h = 120;
        CGFloat w = logo.size.width * (h / logo.size.height);
        CGFloat x = (pageRect.size.width - w) / 2.0;
        [logo drawInRect:CGRectMake(x, y, w, h)];
        y += h ;
    }

    // =========================
    // Title
    // =========================
    [kLang(@"SalesBillTitle")
     drawInRect:CGRectMake(pagePadding, y,
                           pageRect.size.width - pagePadding * 2, 40)
     withAttributes:@{
        NSFontAttributeName: titleFont,
        NSParagraphStyleAttributeName: ({
            NSMutableParagraphStyle *p = [NSMutableParagraphStyle new];
            p.alignment = NSTextAlignmentCenter;
            p;
        })
     }];

    y += 50;

    // =========================
    // Card Background
    // =========================
    CGFloat cardX = pagePadding;
    CGFloat cardWidth = pageRect.size.width - pagePadding * 2;
    CGFloat cardY = y;
    CGFloat cardPadding = 36;


    
    CGContextSetFillColorWithColor(ctx, [UIColor colorWithWhite:0.97 alpha:1].CGColor);
    CGRect cardRect = CGRectMake(cardX, cardY+10, cardWidth, 420);
    #if TARGET_OS_IOS || TARGET_OS_TV
        UIBezierPath *roundedPath = [UIBezierPath bezierPathWithRoundedRect:cardRect cornerRadius:14.0];
        CGContextAddPath(ctx, roundedPath.CGPath);
        CGContextFillPath(ctx);
    #else
        // Fallback using CGPath for non-iOS platforms
        CGPathRef path = CGPathCreateWithRoundedRect(cardRect, 14.0, 14.0, NULL);
        CGContextAddPath(ctx, path);
        CGContextFillPath(ctx);
        CGPathRelease(path);
    #endif

    y = cardY + cardPadding;

   
    
    // =========================
    // Section: Details
    // =========================
    [kLang(@"InvoiceDetails")
     drawInRect:CGRectMake(cardX + cardPadding, y,
                           cardWidth - cardPadding * 2, 24)
     withAttributes:@{
        NSFontAttributeName: sectionFont,
        NSParagraphStyleAttributeName: ({
            NSMutableParagraphStyle *p = [NSMutableParagraphStyle new];
            p.alignment = isRTL ? NSTextAlignmentRight : NSTextAlignmentLeft;
            p;
        })
     }];

    y += 34;

    // =========================
    // Columns
    // =========================
    CGFloat labelWidth = 150;
    CGFloat valueWidth = cardWidth - cardPadding * 2 - labelWidth - 10;

    CGFloat labelX = isRTL
        ? cardX + cardWidth - cardPadding - labelWidth
        : cardX + cardPadding;

    CGFloat valueX = isRTL
        ? cardX + cardPadding
        : labelX + labelWidth + 10;

    void (^drawRow)(NSString *, NSString *) =
    ^(NSString *label, NSString *value) {

        [label drawInRect:CGRectMake(labelX, y, labelWidth, 30)
           withAttributes:@{
            NSFontAttributeName: labelFont,
            NSForegroundColorAttributeName: UIColor.secondaryLabelColor,
            NSParagraphStyleAttributeName: ({
                NSMutableParagraphStyle *p = [NSMutableParagraphStyle new];
                p.alignment = NSTextAlignmentRight;
                p;
            })
        }];

        [value drawInRect:CGRectMake(valueX, y, valueWidth, 30)
           withAttributes:@{
            NSFontAttributeName: valueFont,
            NSParagraphStyleAttributeName: ({
                NSMutableParagraphStyle *p = [NSMutableParagraphStyle new];
                p.alignment = NSTextAlignmentLeft;
                p;
            })
        }];

        y += 28;
    };

    drawRow(kLang(@"BillDate"), [self formattedDate:buyer.sellDate]);
    drawRow(kLang(@"BuyerName"), buyer.buyerName ?: kLang(@"EmptyValue"));
    drawRow(kLang(@"Mobile"), buyer.buyerMobile ?: kLang(@"EmptyValue"));
    drawRow(kLang(@"BirdTitle"), card.CardTitle ?: kLang(@"EmptyValue"));
    drawRow(kLang(@"RingID"), card.RingID ?: kLang(@"EmptyValue"));

    // =========================
    // Section: Amount
    // =========================
    y += 60;
 
    labelX = isRTL
        ? cardX + cardWidth - cardPadding - labelWidth
        : cardX + cardPadding;

    [kLang(@"TotalAmount")
     drawInRect:CGRectMake(cardX + cardPadding, y,
                           cardWidth - cardPadding * 2, 24)
     withAttributes:@{
        NSFontAttributeName: amountFont,
        NSParagraphStyleAttributeName: ({
            NSMutableParagraphStyle *p = [NSMutableParagraphStyle new];
            p.alignment = isRTL ? NSTextAlignmentRight : NSTextAlignmentLeft;
            p;
        })
     }];

 
    NSString *amount =
    [NSString stringWithFormat:@"%@ %@", buyer.buyerPrice ?: @"0", kLang(@"currency")];

    [amount drawInRect:CGRectMake(cardX + cardPadding, y,
                                  cardWidth - cardPadding * 2, 30)
        withAttributes:@{
            NSFontAttributeName: amountFont,
            NSParagraphStyleAttributeName: ({
                NSMutableParagraphStyle *p = [NSMutableParagraphStyle new];
        p.alignment = isRTL ? NSTextAlignmentLeft : NSTextAlignmentRight;
                p;
            })
        }];

    // =========================
    // Footer
    // =========================
    NSString *footer = kLang(@"SalesBillFooter");

    [footer drawInRect:CGRectMake(pagePadding,
                                  pageRect.size.height - 60,
                                  pageRect.size.width - pagePadding * 2,
                                  20)
        withAttributes:@{
            NSFontAttributeName: labelFont,
            NSParagraphStyleAttributeName: ({
                NSMutableParagraphStyle *p = [NSMutableParagraphStyle new];
                p.alignment = NSTextAlignmentCenter;
                p;
            })
        }];

    UIGraphicsEndPDFContext();
    
 
    if (autoShow) {
        dispatch_async(dispatch_get_main_queue(), ^{
            PPPDFViewController *vc = [PPPDFViewController new];
            vc.pdfURL = url;
            vc.cardModel = card;

            [PPFunc presentSheetFrom:AppMgr.topViewController
                             sheetVC:vc
                        detentStyle:PPSheetDetentStyle70];
        });
    }

   
    return url;
}

+ (NSString *)formattedDate:(NSDate *)date
{
    NSDateFormatter *df = [NSDateFormatter new];
    df.locale = [NSLocale currentLocale];
    df.dateStyle = NSDateFormatterMediumStyle;
    return date ? [df stringFromDate:date] : kLang(@"EmptyValue");
}

@end











#import <PDFKit/PDFKit.h>



@interface PPPDFViewController ()
@property (nonatomic, strong) PDFView *pdfView;
@property (nonatomic, strong) UIToolbar *toolBar;
@end

@implementation PPPDFViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.view.backgroundColor = PPBackgroundColorForIOS26(UIColor.systemBackgroundColor);

    [self setupPDFView];
    [self setupToolBar];
}

#pragma mark - UI

- (void)setupPDFView
{
    self.pdfView = [[PDFView alloc] initWithFrame:CGRectZero];
    self.pdfView.translatesAutoresizingMaskIntoConstraints = NO;
    self.pdfView.autoScales = YES;

    // Rounded PDF page appearance
    self.pdfView.documentView.layer.cornerRadius = 16.0;
    self.pdfView.documentView.layer.masksToBounds = YES;
    self.pdfView.backgroundColor = UIColor.clearColor;
   // self.pdfView.layer.cornerRadius = 0;
    self.pdfView.documentView.clipsToBounds = YES;
    if (self.pdfURL) {
        self.pdfView.document = [[PDFDocument alloc] initWithURL:self.pdfURL];
        
    }

    [self.view addSubview:self.pdfView];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.pdfView.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:-10],
        [self.pdfView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:-5],
        [self.pdfView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:5],
        [self.pdfView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:-66]
    ]];
}

- (void)setupToolBar
{
    self.toolBar = [[UIToolbar alloc] init];
    self.toolBar.translatesAutoresizingMaskIntoConstraints = NO;

    UIBarButtonItem *share =
    [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"square.and.arrow.up"]
                                     style:UIBarButtonItemStylePlain
                                    target:self
                                    action:@selector(onShare)];

    UIBarButtonItem *save =
    [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"tray.and.arrow.down"]
                                     style:UIBarButtonItemStylePlain
                                    target:self
                                    action:@selector(onSave)];

    UIBarButtonItem *card =
    [[UIBarButtonItem alloc] initWithTitle:kLang(@"ViewBirdCard")
                                     style:UIBarButtonItemStylePlain
                                    target:self
                                    action:@selector(onViewCard)];

    UIBarButtonItem *returnBill =
    [[UIBarButtonItem alloc] initWithTitle:kLang(@"ReturnBill")
                                     style:UIBarButtonItemStylePlain
                                    target:self
                                    action:@selector(onReturn)];
    
    UIFont *barFont =
    [GM boldFontWithSize:16] ?: [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];

    NSDictionary *attrs = @{
        NSFontAttributeName: barFont
    };

    [card setTitleTextAttributes:attrs forState:UIControlStateNormal];
    [card setTitleTextAttributes:attrs forState:UIControlStateHighlighted];

    [returnBill setTitleTextAttributes:attrs forState:UIControlStateNormal];
    [returnBill setTitleTextAttributes:attrs forState:UIControlStateHighlighted];

    UIBarButtonItem *flex = [[UIBarButtonItem alloc]
                             initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                             target:nil action:nil];

    self.toolBar.items = @[
        share, flex,
        save,  flex,
        card,  flex,
        returnBill
    ];

    [self.view addSubview:self.toolBar];

    [NSLayoutConstraint activateConstraints:@[
        [self.toolBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.toolBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.toolBar.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.toolBar.heightAnchor constraintEqualToConstant:56]
    ]];
}

#pragma mark - Actions

- (void)onShare
{
    if (!self.pdfURL) return;

    UIActivityViewController *vc =
    [[UIActivityViewController alloc] initWithActivityItems:@[self.pdfURL]
                                      applicationActivities:nil];

    vc.popoverPresentationController.sourceView = self.view;
    vc.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds),
                                                              CGRectGetMidY(self.view.bounds),
                                                              0, 0);
    vc.popoverPresentationController.permittedArrowDirections = 0;
    [self presentViewController:vc animated:YES completion:nil];
}

- (void)onSave
{
    if (!self.pdfURL) return;

    UIDocumentPickerViewController *picker =
    [[UIDocumentPickerViewController alloc] initForExportingURLs:@[self.pdfURL]];

    [self presentViewController:picker animated:YES completion:nil];
}

- (void)onViewCard
{
    if (!self.cardModel) return;

    // 🔁 Hook this to your existing Card Details flow
    [[NSNotificationCenter defaultCenter]
     postNotificationName:@"PPShowCardDetails"
     object:self.cardModel];
}

- (void)onReturn
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
