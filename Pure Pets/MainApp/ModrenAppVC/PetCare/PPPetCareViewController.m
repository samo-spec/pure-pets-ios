#import "PPPetCareViewController.h"
#import "PPUniversalCell.h"
#import "PPUniversalCellViewModel.h"
#import "PPImageLoaderManager.h"
#import "PPOverlayCoordinator.h"
#import "PetAccessory.h"
#import "PetAccessoryManager.h"
#import "VetManager.h"
#import "VetModel.h"
#import "MainKindsModel.h"
#import "ArabicNormalizer.h"
#import "CartManager.h"
#import "CartViewController.h"
#import "PPNavigationController.h"
#import "PPRootTabBarController.h"
#import "PPHomeHelper.h"
#import "UIView+Badge.h"
#import "AppClasses.h"
#import "PPNetworkRetryHelper.h"
#import "PPAlertHelper.h"
#import "PPHUD.h"
#import "PPFunc.h"
#import "PPPetCareVetCell.h"
 
#import "PPPetCareViewerVC.h"
#import "PPPetCareVetViewrVC.h"

typedef NS_ENUM(NSInteger, PPPetCareMedicineFilter) {
    PPPetCareMedicineFilterAll = 0,
    PPPetCareMedicineFilterAvailable,
    PPPetCareMedicineFilterInStock,
    PPPetCareMedicineFilterNew
};

typedef NS_ENUM(NSInteger, PPPetCareVetFilter) {
    PPPetCareVetFilterAll = 0,
    PPPetCareVetFilterWithPhone,
    PPPetCareVetFilterCompany,
    PPPetCareVetFilterPersonal
};



static CGFloat PPPetCareNavigationSegmentWidth(void)
{
    CGFloat screenWidth = CGRectGetWidth(UIScreen.mainScreen.bounds);
    CGFloat availableWidth = screenWidth > 0.0 ? screenWidth - 150.0 : 280.0;
    return floor(MAX(280.0, MIN(320.0, availableWidth)));
}



static UIColor *PPPetCareSearchSurfaceColor(void)
{
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traitCollection) {
            BOOL dark = traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
            return dark
                ? [UIColor colorWithWhite:0.12 alpha:0.86]
                : [UIColor colorWithWhite:1.0 alpha:0.88];
        }];
    }
    return [UIColor colorWithWhite:1.0 alpha:0.88];
}

static UIColor *PPPetCareSearchBorderColor(void)
{
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traitCollection) {
            BOOL dark = traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
            return dark
                ? [UIColor colorWithWhite:1.0 alpha:0.10]
                : [UIColor colorWithWhite:1.0 alpha:0.56];
        }];
    }
    return [UIColor colorWithWhite:1.0 alpha:0.56];
}

static NSString *PPPetCareNormalizedText(NSString *value)
{
    NSString *trimmed = [PPPetCareSafeString(value) stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (trimmed.length == 0) {
        return @"";
    }
    NSString *normalized = [ArabicNormalizer normalize:trimmed] ?: trimmed;
    return normalized.lowercaseString;
}

static NSString *PPPetCareHeroAnimationName(PPPetCareInitialSection section)
{
    return section == PPPetCareInitialSectionVeterinarians ? @"Femaleveterinarian" : @"pet-care4";
}
static NSString *PPPetCarePremiumMedicineHeroAnimationBase64(void)
{
    return
    @"eyJ2IjoiNS43LjQiLCJmciI6NjAsImlwIjowLCJvcCI6MTgwLCJ3IjoyNTYsImgiOjI1Niwibm0iOiJQZXRDYXJlIE1lZGljaW5lIEhlcm8iLCJkZGQiOjAs"
    @"ImFzc2V0cyI6W10sImxheWVycyI6W3siZGRkIjowLCJpbmQiOjEsInR5Ijo0LCJubSI6IkhhbG8iLCJzciI6MSwia3MiOnsibyI6eyJhIjoxLCJrIjpbeyJ0"
    @"IjowLCJzIjpbMThdLCJlIjpbMzBdLCJpIjp7IngiOlswLjY2N10sInkiOlsxXX0sIm8iOnsieCI6WzAuMzMzXSwieSI6WzBdfX0seyJ0Ijo5MCwicyI6WzMw"
    @"XSwiZSI6WzE4XSwiaSI6eyJ4IjpbMC42NjddLCJ5IjpbMV19LCJvIjp7IngiOlswLjMzM10sInkiOlswXX19LHsidCI6MTgwLCJzIjpbMThdfV19LCJyIjp7"
    @"ImEiOjAsImsiOlswXX0sInAiOnsiYSI6MSwiayI6W3sidCI6MCwicyI6WzEyOCwxMjYsMF0sImUiOlsxMjgsMTMyLDBdLCJpIjp7IngiOlswLjY2N10sInki"
    @"OlsxXX0sIm8iOnsieCI6WzAuMzMzXSwieSI6WzBdfX0seyJ0Ijo5MCwicyI6WzEyOCwxMzIsMF0sImUiOlsxMjgsMTI2LDBdLCJpIjp7IngiOlswLjY2N10s"
    @"InkiOlsxXX0sIm8iOnsieCI6WzAuMzMzXSwieSI6WzBdfX0seyJ0IjoxODAsInMiOlsxMjgsMTI2LDBdfV19LCJhIjp7ImEiOjAsImsiOlswLDAsMF19LCJz"
    @"Ijp7ImEiOjEsImsiOlt7InQiOjAsInMiOls4Miw4MiwxMDBdLCJlIjpbMTA2LDEwNiwxMDBdLCJpIjp7IngiOlswLjY2N10sInkiOlsxXX0sIm8iOnsieCI6"
    @"WzAuMzMzXSwieSI6WzBdfX0seyJ0Ijo5MCwicyI6WzEwNiwxMDYsMTAwXSwiZSI6WzgyLDgyLDEwMF0sImkiOnsieCI6WzAuNjY3XSwieSI6WzFdfSwibyI6"
    @"eyJ4IjpbMC4zMzNdLCJ5IjpbMF19fSx7InQiOjE4MCwicyI6WzgyLDgyLDEwMF19XX19LCJhbyI6MCwic2hhcGVzIjpbeyJ0eSI6ImdyIiwibm0iOiJIYWxv"
    @"IEdyb3VwIiwiaXQiOlt7InR5IjoiZWwiLCJkIjoxLCJwIjp7ImEiOjAsImsiOlswLDBdfSwicyI6eyJhIjowLCJrIjpbMTY4LDE2OF19LCJubSI6IkVsbGlw"
    @"c2UgUGF0aCAxIn0seyJ0eSI6ImZsIiwiYyI6eyJhIjowLCJrIjpbMC45ODgsMC42MTIsMC4zMzcsMV19LCJvIjp7ImEiOjAsImsiOjEwMH0sInIiOjEsImJt"
    @"IjowLCJubSI6IkZpbGwgMSJ9LHsidHkiOiJ0ciIsInAiOnsiYSI6MCwiayI6WzAsMF19LCJhIjp7ImEiOjAsImsiOlswLDBdfSwicyI6eyJhIjowLCJrIjpb"
    @"MTAwLDEwMF19LCJyIjp7ImEiOjAsImsiOlswXX0sIm8iOnsiYSI6MCwiayI6MTAwfSwic2siOnsiYSI6MCwiayI6WzBdfSwic2EiOnsiYSI6MCwiayI6WzBd"
    @"fSwibm0iOiJUcmFuc2Zvcm0ifV19XSwiaXAiOjAsIm9wIjoxODAsInN0IjowLCJibSI6MH0seyJkZGQiOjAsImluZCI6MiwidHkiOjQsIm5tIjoiUmluZyIs"
    @"InNyIjoxLCJrcyI6eyJvIjp7ImEiOjEsImsiOlt7InQiOjAsInMiOlszNF0sImUiOls1NF0sImkiOnsieCI6WzAuNjY3XSwieSI6WzFdfSwibyI6eyJ4Ijpb"
    @"MC4zMzNdLCJ5IjpbMF19fSx7InQiOjkwLCJzIjpbNTRdLCJlIjpbMzRdLCJpIjp7IngiOlswLjY2N10sInkiOlsxXX0sIm8iOnsieCI6WzAuMzMzXSwieSI6"
    @"WzBdfX0seyJ0IjoxODAsInMiOlszNF19XX0sInIiOnsiYSI6MSwiayI6W3sidCI6MCwicyI6WzBdLCJlIjpbMzYwXSwiaSI6eyJ4IjpbMC42NjddLCJ5Ijpb"
    @"MV19LCJvIjp7IngiOlswLjMzM10sInkiOlswXX19LHsidCI6MTgwLCJzIjpbMzYwXX1dfSwicCI6eyJhIjowLCJrIjpbMTI4LDEyOCwwXX0sImEiOnsiYSI6"
    @"MCwiayI6WzAsMCwwXX0sInMiOnsiYSI6MSwiayI6W3sidCI6MCwicyI6Wzk0LDk0LDEwMF0sImUiOlsxMDIsMTAyLDEwMF0sImkiOnsieCI6WzAuNjY3XSwi"
    @"eSI6WzFdfSwibyI6eyJ4IjpbMC4zMzNdLCJ5IjpbMF19fSx7InQiOjkwLCJzIjpbMTAyLDEwMiwxMDBdLCJlIjpbOTQsOTQsMTAwXSwiaSI6eyJ4IjpbMC42"
    @"NjddLCJ5IjpbMV19LCJvIjp7IngiOlswLjMzM10sInkiOlswXX19LHsidCI6MTgwLCJzIjpbOTQsOTQsMTAwXX1dfX0sImFvIjowLCJzaGFwZXMiOlt7InR5"
    @"IjoiZ3IiLCJubSI6IlJpbmcgR3JvdXAiLCJpdCI6W3sidHkiOiJlbCIsImQiOjEsInAiOnsiYSI6MCwiayI6WzAsMF19LCJzIjp7ImEiOjAsImsiOlsxNzAs"
    @"MTcwXX0sIm5tIjoiRWxsaXBzZSBQYXRoIDEifSx7InR5Ijoic3QiLCJjIjp7ImEiOjAsImsiOlsxLDAuOTI5LDAuODMxLDFdfSwibyI6eyJhIjowLCJrIjox"
    @"MDB9LCJ3Ijp7ImEiOjAsImsiOls0XX0sImxjIjoyLCJsaiI6MiwibWwiOjQsImJtIjowLCJubSI6IlN0cm9rZSAxIn0seyJ0eSI6InRyIiwicCI6eyJhIjow"
    @"LCJrIjpbMCwwXX0sImEiOnsiYSI6MCwiayI6WzAsMF19LCJzIjp7ImEiOjAsImsiOlsxMDAsMTAwXX0sInIiOnsiYSI6MCwiayI6WzBdfSwibyI6eyJhIjow"
    @"LCJrIjoxMDB9LCJzayI6eyJhIjowLCJrIjpbMF19LCJzYSI6eyJhIjowLCJrIjpbMF19LCJubSI6IlRyYW5zZm9ybSJ9XX1dLCJpcCI6MCwib3AiOjE4MCwi"
    @"c3QiOjAsImJtIjowfSx7ImRkZCI6MCwiaW5kIjozLCJ0eSI6NCwibm0iOiJTcGFya2xlcyIsInNyIjoxLCJrcyI6eyJvIjp7ImEiOjEsImsiOlt7InQiOjAs"
    @"InMiOls0Nl0sImUiOls3Ml0sImkiOnsieCI6WzAuNjY3XSwieSI6WzFdfSwibyI6eyJ4IjpbMC4zMzNdLCJ5IjpbMF19fSx7InQiOjkwLCJzIjpbNzJdLCJl"
    @"IjpbNDZdLCJpIjp7IngiOlswLjY2N10sInkiOlsxXX0sIm8iOnsieCI6WzAuMzMzXSwieSI6WzBdfX0seyJ0IjoxODAsInMiOls0Nl19XX0sInIiOnsiYSI6"
    @"MSwiayI6W3sidCI6MCwicyI6WzBdLCJlIjpbLTM2MF0sImkiOnsieCI6WzAuNjY3XSwieSI6WzFdfSwibyI6eyJ4IjpbMC4zMzNdLCJ5IjpbMF19fSx7InQi"
    @"OjE4MCwicyI6Wy0zNjBdfV19LCJwIjp7ImEiOjEsImsiOlt7InQiOjAsInMiOlsxMjgsMTI2LDBdLCJlIjpbMTI4LDEzMCwwXSwiaSI6eyJ4IjpbMC42Njdd"
    @"LCJ5IjpbMV19LCJvIjp7IngiOlswLjMzM10sInkiOlswXX19LHsidCI6OTAsInMiOlsxMjgsMTMwLDBdLCJlIjpbMTI4LDEyNiwwXSwiaSI6eyJ4IjpbMC42"
    @"NjddLCJ5IjpbMV19LCJvIjp7IngiOlswLjMzM10sInkiOlswXX19LHsidCI6MTgwLCJzIjpbMTI4LDEyNiwwXX1dfSwiYSI6eyJhIjowLCJrIjpbMCwwLDBd"
    @"fSwicyI6eyJhIjoxLCJrIjpbeyJ0IjowLCJzIjpbOTYsOTYsMTAwXSwiZSI6WzEwNCwxMDQsMTAwXSwiaSI6eyJ4IjpbMC42NjddLCJ5IjpbMV19LCJvIjp7"
    @"IngiOlswLjMzM10sInkiOlswXX19LHsidCI6OTAsInMiOlsxMDQsMTA0LDEwMF0sImUiOls5Niw5NiwxMDBdLCJpIjp7IngiOlswLjY2N10sInkiOlsxXX0s"
    @"Im8iOnsieCI6WzAuMzMzXSwieSI6WzBdfX0seyJ0IjoxODAsInMiOls5Niw5NiwxMDBdfV19fSwiYW8iOjAsInNoYXBlcyI6W3sidHkiOiJnciIsIm5tIjoi"
    @"U3BhcmtsZSBBIiwiaXQiOlt7InR5IjoiZWwiLCJkIjoxLCJwIjp7ImEiOjAsImsiOlstNjQsLTQyXX0sInMiOnsiYSI6MCwiayI6WzE4LDE4XX0sIm5tIjoi"
    @"RWxsaXBzZSBQYXRoIDEifSx7InR5IjoiZmwiLCJjIjp7ImEiOjAsImsiOlsxLDAuODUxLDAuNjYzLDFdfSwibyI6eyJhIjowLCJrIjoxMDB9LCJyIjoxLCJi"
    @"bSI6MCwibm0iOiJGaWxsIDEifSx7InR5IjoidHIiLCJwIjp7ImEiOjAsImsiOlswLDBdfSwiYSI6eyJhIjowLCJrIjpbMCwwXX0sInMiOnsiYSI6MCwiayI6"
    @"WzEwMCwxMDBdfSwiciI6eyJhIjowLCJrIjpbMF19LCJvIjp7ImEiOjAsImsiOjEwMH0sInNrIjp7ImEiOjAsImsiOlswXX0sInNhIjp7ImEiOjAsImsiOlsw"
    @"XX0sIm5tIjoiVHJhbnNmb3JtIn1dfSx7InR5IjoiZ3IiLCJubSI6IlNwYXJrbGUgQiIsIml0IjpbeyJ0eSI6ImVsIiwiZCI6MSwicCI6eyJhIjowLCJrIjpb"
    @"NjgsLTE4XX0sInMiOnsiYSI6MCwiayI6WzEyLDEyXX0sIm5tIjoiRWxsaXBzZSBQYXRoIDEifSx7InR5IjoiZmwiLCJjIjp7ImEiOjAsImsiOlswLjk5Miww"
    @"Ljk3MywwLjk0OSwxXX0sIm8iOnsiYSI6MCwiayI6MTAwfSwiciI6MSwiYm0iOjAsIm5tIjoiRmlsbCAxIn0seyJ0eSI6InRyIiwicCI6eyJhIjowLCJrIjpb"
    @"MCwwXX0sImEiOnsiYSI6MCwiayI6WzAsMF19LCJzIjp7ImEiOjAsImsiOlsxMDAsMTAwXX0sInIiOnsiYSI6MCwiayI6WzBdfSwibyI6eyJhIjowLCJrIjox"
    @"MDB9LCJzayI6eyJhIjowLCJrIjpbMF19LCJzYSI6eyJhIjowLCJrIjpbMF19LCJubSI6IlRyYW5zZm9ybSJ9XX0seyJ0eSI6ImdyIiwibm0iOiJTcGFya2xl"
    @"IEMiLCJpdCI6W3sidHkiOiJlbCIsImQiOjEsInAiOnsiYSI6MCwiayI6WzQsNzJdfSwicyI6eyJhIjowLCJrIjpbMTYsMTZdfSwibm0iOiJFbGxpcHNlIFBh"
    @"dGggMSJ9LHsidHkiOiJmbCIsImMiOnsiYSI6MCwiayI6WzAuOTc2LDAuNzMzLDAuNDc1LDFdfSwibyI6eyJhIjowLCJrIjoxMDB9LCJyIjoxLCJibSI6MCwi"
    @"bm0iOiJGaWxsIDEifSx7InR5IjoidHIiLCJwIjp7ImEiOjAsImsiOlswLDBdfSwiYSI6eyJhIjowLCJrIjpbMCwwXX0sInMiOnsiYSI6MCwiayI6WzEwMCwx"
    @"MDBdfSwiciI6eyJhIjowLCJrIjpbMF19LCJvIjp7ImEiOjAsImsiOjEwMH0sInNrIjp7ImEiOjAsImsiOlswXX0sInNhIjp7ImEiOjAsImsiOlswXX0sIm5t"
    @"IjoiVHJhbnNmb3JtIn1dfV0sImlwIjowLCJvcCI6MTgwLCJzdCI6MCwiYm0iOjB9LHsiZGRkIjowLCJpbmQiOjQsInR5Ijo0LCJubSI6Ik1lZGljaW5lIElj"
    @"b24iLCJzciI6MSwia3MiOnsibyI6eyJhIjowLCJrIjpbMTAwXX0sInIiOnsiYSI6MSwiayI6W3sidCI6MCwicyI6Wy04XSwiZSI6WzhdLCJpIjp7IngiOlsw"
    @"LjY2N10sInkiOlsxXX0sIm8iOnsieCI6WzAuMzMzXSwieSI6WzBdfX0seyJ0Ijo5MCwicyI6WzhdLCJlIjpbLThdLCJpIjp7IngiOlswLjY2N10sInkiOlsx"
    @"XX0sIm8iOnsieCI6WzAuMzMzXSwieSI6WzBdfX0seyJ0IjoxODAsInMiOlstOF19XX0sInAiOnsiYSI6MSwiayI6W3sidCI6MCwicyI6WzEyOCwxMjgsMF0s"
    @"ImUiOlsxMjgsMTIyLDBdLCJpIjp7IngiOlswLjY2N10sInkiOlsxXX0sIm8iOnsieCI6WzAuMzMzXSwieSI6WzBdfX0seyJ0Ijo5MCwicyI6WzEyOCwxMjIs"
    @"MF0sImUiOlsxMjgsMTI4LDBdLCJpIjp7IngiOlswLjY2N10sInkiOlsxXX0sIm8iOnsieCI6WzAuMzMzXSwieSI6WzBdfX0seyJ0IjoxODAsInMiOlsxMjgs"
    @"MTI4LDBdfV19LCJhIjp7ImEiOjAsImsiOlswLDAsMF19LCJzIjp7ImEiOjEsImsiOlt7InQiOjAsInMiOls5Miw5MiwxMDBdLCJlIjpbMTAwLDEwMCwxMDBd"
    @"LCJpIjp7IngiOlswLjY2N10sInkiOlsxXX0sIm8iOnsieCI6WzAuMzMzXSwieSI6WzBdfX0seyJ0Ijo0NSwicyI6WzEwMCwxMDAsMTAwXSwiZSI6Wzk2LDk2"
    @"LDEwMF0sImkiOnsieCI6WzAuNjY3XSwieSI6WzFdfSwibyI6eyJ4IjpbMC4zMzNdLCJ5IjpbMF19fSx7InQiOjkwLCJzIjpbOTYsOTYsMTAwXSwiZSI6WzEw"
    @"MCwxMDAsMTAwXSwiaSI6eyJ4IjpbMC42NjddLCJ5IjpbMV19LCJvIjp7IngiOlswLjMzM10sInkiOlswXX19LHsidCI6MTgwLCJzIjpbOTIsOTIsMTAwXX1d"
    @"fX0sImFvIjowLCJzaGFwZXMiOlt7InR5IjoiZ3IiLCJubSI6IkxlZnQgQ2Fwc3VsZSIsIml0IjpbeyJ0eSI6InJjIiwiZCI6MSwicCI6eyJhIjowLCJrIjpb"
    @"LTE4LDBdfSwicyI6eyJhIjowLCJrIjpbOTAsNTBdfSwiciI6eyJhIjowLCJrIjpbMjVdfSwibm0iOiJSZWN0YW5nbGUgUGF0aCAxIn0seyJ0eSI6ImZsIiwi"
    @"YyI6eyJhIjowLCJrIjpbMC45OTIsMC45NzMsMC45NDksMV19LCJvIjp7ImEiOjAsImsiOjEwMH0sInIiOjEsImJtIjowLCJubSI6IkZpbGwgMSJ9LHsidHki"
    @"OiJ0ciIsInAiOnsiYSI6MCwiayI6WzAsMF19LCJhIjp7ImEiOjAsImsiOlswLDBdfSwicyI6eyJhIjowLCJrIjpbMTAwLDEwMF19LCJyIjp7ImEiOjAsImsi"
    @"OlswXX0sIm8iOnsiYSI6MCwiayI6MTAwfSwic2siOnsiYSI6MCwiayI6WzBdfSwic2EiOnsiYSI6MCwiayI6WzBdfSwibm0iOiJUcmFuc2Zvcm0ifV19LHsi"
    @"dHkiOiJnciIsIm5tIjoiUmlnaHQgQ2Fwc3VsZSIsIml0IjpbeyJ0eSI6InJjIiwiZCI6MSwicCI6eyJhIjowLCJrIjpbMTgsMF19LCJzIjp7ImEiOjAsImsi"
    @"Ols5MCw1MF19LCJyIjp7ImEiOjAsImsiOlsyNV19LCJubSI6IlJlY3RhbmdsZSBQYXRoIDEifSx7InR5IjoiZmwiLCJjIjp7ImEiOjAsImsiOlswLjk3Myww"
    @"LjU5MiwwLjI4MiwxXX0sIm8iOnsiYSI6MCwiayI6MTAwfSwiciI6MSwiYm0iOjAsIm5tIjoiRmlsbCAxIn0seyJ0eSI6InRyIiwicCI6eyJhIjowLCJrIjpb"
    @"MCwwXX0sImEiOnsiYSI6MCwiayI6WzAsMF19LCJzIjp7ImEiOjAsImsiOlsxMDAsMTAwXX0sInIiOnsiYSI6MCwiayI6WzBdfSwibyI6eyJhIjowLCJrIjox"
    @"MDB9LCJzayI6eyJhIjowLCJrIjpbMF19LCJzYSI6eyJhIjowLCJrIjpbMF19LCJubSI6IlRyYW5zZm9ybSJ9XX0seyJ0eSI6ImdyIiwibm0iOiJEaXZpZGVy"
    @"IiwiaXQiOlt7InR5IjoicmMiLCJkIjoxLCJwIjp7ImEiOjAsImsiOlswLDBdfSwicyI6eyJhIjowLCJrIjpbMTIsNThdfSwiciI6eyJhIjowLCJrIjpbNl19"
    @"LCJubSI6IlJlY3RhbmdsZSBQYXRoIDEifSx7InR5IjoiZmwiLCJjIjp7ImEiOjAsImsiOlsxLDEsMSwxXX0sIm8iOnsiYSI6MCwiayI6Mjh9LCJyIjoxLCJi"
    @"bSI6MCwibm0iOiJGaWxsIDEifSx7InR5IjoidHIiLCJwIjp7ImEiOjAsImsiOlswLDBdfSwiYSI6eyJhIjowLCJrIjpbMCwwXX0sInMiOnsiYSI6MCwiayI6"
    @"WzEwMCwxMDBdfSwiciI6eyJhIjowLCJrIjpbMF19LCJvIjp7ImEiOjAsImsiOjEwMH0sInNrIjp7ImEiOjAsImsiOlswXX0sInNhIjp7ImEiOjAsImsiOlsw"
    @"XX0sIm5tIjoiVHJhbnNmb3JtIn1dfSx7InR5IjoiZ3IiLCJubSI6IkFjY2VudCBEb3QiLCJpdCI6W3sidHkiOiJlbCIsImQiOjEsInAiOnsiYSI6MCwiayI6"
    @"Wy0yNiwtNF19LCJzIjp7ImEiOjAsImsiOlsyMiwyMl19LCJubSI6IkVsbGlwc2UgUGF0aCAxIn0seyJ0eSI6ImZsIiwiYyI6eyJhIjowLCJrIjpbMSwxLDEs"
    @"MV19LCJvIjp7ImEiOjAsImsiOjIyfSwiciI6MSwiYm0iOjAsIm5tIjoiRmlsbCAxIn0seyJ0eSI6InRyIiwicCI6eyJhIjowLCJrIjpbMCwwXX0sImEiOnsi"
    @"YSI6MCwiayI6WzAsMF19LCJzIjp7ImEiOjAsImsiOlsxMDAsMTAwXX0sInIiOnsiYSI6MCwiayI6WzBdfSwibyI6eyJhIjowLCJrIjoxMDB9LCJzayI6eyJh"
    @"IjowLCJrIjpbMF19LCJzYSI6eyJhIjowLCJrIjpbMF19LCJubSI6IlRyYW5zZm9ybSJ9XX1dLCJpcCI6MCwib3AiOjE4MCwic3QiOjAsImJtIjowfV19";
}

static NSString *PPPetCarePremiumVetHeroAnimationBase64(void)
{
    return
    @"eyJ2IjoiNS43LjQiLCJmciI6NjAsImlwIjowLCJvcCI6MTgwLCJ3IjoyNTYsImgiOjI1Niwibm0iOiJQZXRDYXJlIFZldCBIZXJvIiwiZGRkIjowLCJhc3Nl"
    @"dHMiOltdLCJsYXllcnMiOlt7ImRkZCI6MCwiaW5kIjoxLCJ0eSI6NCwibm0iOiJIYWxvIiwic3IiOjEsImtzIjp7Im8iOnsiYSI6MSwiayI6W3sidCI6MCwi"
    @"cyI6WzE4XSwiZSI6WzMwXSwiaSI6eyJ4IjpbMC42NjddLCJ5IjpbMV19LCJvIjp7IngiOlswLjMzM10sInkiOlswXX19LHsidCI6OTAsInMiOlszMF0sImUi"
    @"OlsxOF0sImkiOnsieCI6WzAuNjY3XSwieSI6WzFdfSwibyI6eyJ4IjpbMC4zMzNdLCJ5IjpbMF19fSx7InQiOjE4MCwicyI6WzE4XX1dfSwiciI6eyJhIjow"
    @"LCJrIjpbMF19LCJwIjp7ImEiOjEsImsiOlt7InQiOjAsInMiOlsxMjgsMTI2LDBdLCJlIjpbMTI4LDEzMiwwXSwiaSI6eyJ4IjpbMC42NjddLCJ5IjpbMV19"
    @"LCJvIjp7IngiOlswLjMzM10sInkiOlswXX19LHsidCI6OTAsInMiOlsxMjgsMTMyLDBdLCJlIjpbMTI4LDEyNiwwXSwiaSI6eyJ4IjpbMC42NjddLCJ5Ijpb"
    @"MV19LCJvIjp7IngiOlswLjMzM10sInkiOlswXX19LHsidCI6MTgwLCJzIjpbMTI4LDEyNiwwXX1dfSwiYSI6eyJhIjowLCJrIjpbMCwwLDBdfSwicyI6eyJh"
    @"IjoxLCJrIjpbeyJ0IjowLCJzIjpbODIsODIsMTAwXSwiZSI6WzEwNiwxMDYsMTAwXSwiaSI6eyJ4IjpbMC42NjddLCJ5IjpbMV19LCJvIjp7IngiOlswLjMz"
    @"M10sInkiOlswXX19LHsidCI6OTAsInMiOlsxMDYsMTA2LDEwMF0sImUiOls4Miw4MiwxMDBdLCJpIjp7IngiOlswLjY2N10sInkiOlsxXX0sIm8iOnsieCI6"
    @"WzAuMzMzXSwieSI6WzBdfX0seyJ0IjoxODAsInMiOls4Miw4MiwxMDBdfV19fSwiYW8iOjAsInNoYXBlcyI6W3sidHkiOiJnciIsIm5tIjoiSGFsbyBHcm91"
    @"cCIsIml0IjpbeyJ0eSI6ImVsIiwiZCI6MSwicCI6eyJhIjowLCJrIjpbMCwwXX0sInMiOnsiYSI6MCwiayI6WzE2OCwxNjhdfSwibm0iOiJFbGxpcHNlIFBh"
    @"dGggMSJ9LHsidHkiOiJmbCIsImMiOnsiYSI6MCwiayI6WzAuOTg0LDAuNDk4LDAuNTg4LDFdfSwibyI6eyJhIjowLCJrIjoxMDB9LCJyIjoxLCJibSI6MCwi"
    @"bm0iOiJGaWxsIDEifSx7InR5IjoidHIiLCJwIjp7ImEiOjAsImsiOlswLDBdfSwiYSI6eyJhIjowLCJrIjpbMCwwXX0sInMiOnsiYSI6MCwiayI6WzEwMCwx"
    @"MDBdfSwiciI6eyJhIjowLCJrIjpbMF19LCJvIjp7ImEiOjAsImsiOjEwMH0sInNrIjp7ImEiOjAsImsiOlswXX0sInNhIjp7ImEiOjAsImsiOlswXX0sIm5t"
    @"IjoiVHJhbnNmb3JtIn1dfV0sImlwIjowLCJvcCI6MTgwLCJzdCI6MCwiYm0iOjB9LHsiZGRkIjowLCJpbmQiOjIsInR5Ijo0LCJubSI6IlJpbmciLCJzciI6"
    @"MSwia3MiOnsibyI6eyJhIjoxLCJrIjpbeyJ0IjowLCJzIjpbMzRdLCJlIjpbNTRdLCJpIjp7IngiOlswLjY2N10sInkiOlsxXX0sIm8iOnsieCI6WzAuMzMz"
    @"XSwieSI6WzBdfX0seyJ0Ijo5MCwicyI6WzU0XSwiZSI6WzM0XSwiaSI6eyJ4IjpbMC42NjddLCJ5IjpbMV19LCJvIjp7IngiOlswLjMzM10sInkiOlswXX19"
    @"LHsidCI6MTgwLCJzIjpbMzRdfV19LCJyIjp7ImEiOjEsImsiOlt7InQiOjAsInMiOlswXSwiZSI6WzM2MF0sImkiOnsieCI6WzAuNjY3XSwieSI6WzFdfSwi"
    @"byI6eyJ4IjpbMC4zMzNdLCJ5IjpbMF19fSx7InQiOjE4MCwicyI6WzM2MF19XX0sInAiOnsiYSI6MCwiayI6WzEyOCwxMjgsMF19LCJhIjp7ImEiOjAsImsi"
    @"OlswLDAsMF19LCJzIjp7ImEiOjEsImsiOlt7InQiOjAsInMiOls5NCw5NCwxMDBdLCJlIjpbMTAyLDEwMiwxMDBdLCJpIjp7IngiOlswLjY2N10sInkiOlsx"
    @"XX0sIm8iOnsieCI6WzAuMzMzXSwieSI6WzBdfX0seyJ0Ijo5MCwicyI6WzEwMiwxMDIsMTAwXSwiZSI6Wzk0LDk0LDEwMF0sImkiOnsieCI6WzAuNjY3XSwi"
    @"eSI6WzFdfSwibyI6eyJ4IjpbMC4zMzNdLCJ5IjpbMF19fSx7InQiOjE4MCwicyI6Wzk0LDk0LDEwMF19XX19LCJhbyI6MCwic2hhcGVzIjpbeyJ0eSI6Imdy"
    @"Iiwibm0iOiJSaW5nIEdyb3VwIiwiaXQiOlt7InR5IjoiZWwiLCJkIjoxLCJwIjp7ImEiOjAsImsiOlswLDBdfSwicyI6eyJhIjowLCJrIjpbMTcwLDE3MF19"
    @"LCJubSI6IkVsbGlwc2UgUGF0aCAxIn0seyJ0eSI6InN0IiwiYyI6eyJhIjowLCJrIjpbMSwwLjkwMiwwLjkyNSwxXX0sIm8iOnsiYSI6MCwiayI6MTAwfSwi"
    @"dyI6eyJhIjowLCJrIjpbNF19LCJsYyI6MiwibGoiOjIsIm1sIjo0LCJibSI6MCwibm0iOiJTdHJva2UgMSJ9LHsidHkiOiJ0ciIsInAiOnsiYSI6MCwiayI6"
    @"WzAsMF19LCJhIjp7ImEiOjAsImsiOlswLDBdfSwicyI6eyJhIjowLCJrIjpbMTAwLDEwMF19LCJyIjp7ImEiOjAsImsiOlswXX0sIm8iOnsiYSI6MCwiayI6"
    @"MTAwfSwic2siOnsiYSI6MCwiayI6WzBdfSwic2EiOnsiYSI6MCwiayI6WzBdfSwibm0iOiJUcmFuc2Zvcm0ifV19XSwiaXAiOjAsIm9wIjoxODAsInN0Ijow"
    @"LCJibSI6MH0seyJkZGQiOjAsImluZCI6MywidHkiOjQsIm5tIjoiU3BhcmtsZXMiLCJzciI6MSwia3MiOnsibyI6eyJhIjoxLCJrIjpbeyJ0IjowLCJzIjpb"
    @"NDZdLCJlIjpbNzJdLCJpIjp7IngiOlswLjY2N10sInkiOlsxXX0sIm8iOnsieCI6WzAuMzMzXSwieSI6WzBdfX0seyJ0Ijo5MCwicyI6WzcyXSwiZSI6WzQ2"
    @"XSwiaSI6eyJ4IjpbMC42NjddLCJ5IjpbMV19LCJvIjp7IngiOlswLjMzM10sInkiOlswXX19LHsidCI6MTgwLCJzIjpbNDZdfV19LCJyIjp7ImEiOjEsImsi"
    @"Olt7InQiOjAsInMiOlswXSwiZSI6Wy0zNjBdLCJpIjp7IngiOlswLjY2N10sInkiOlsxXX0sIm8iOnsieCI6WzAuMzMzXSwieSI6WzBdfX0seyJ0IjoxODAs"
    @"InMiOlstMzYwXX1dfSwicCI6eyJhIjoxLCJrIjpbeyJ0IjowLCJzIjpbMTI4LDEyNiwwXSwiZSI6WzEyOCwxMzAsMF0sImkiOnsieCI6WzAuNjY3XSwieSI6"
    @"WzFdfSwibyI6eyJ4IjpbMC4zMzNdLCJ5IjpbMF19fSx7InQiOjkwLCJzIjpbMTI4LDEzMCwwXSwiZSI6WzEyOCwxMjYsMF0sImkiOnsieCI6WzAuNjY3XSwi"
    @"eSI6WzFdfSwibyI6eyJ4IjpbMC4zMzNdLCJ5IjpbMF19fSx7InQiOjE4MCwicyI6WzEyOCwxMjYsMF19XX0sImEiOnsiYSI6MCwiayI6WzAsMCwwXX0sInMi"
    @"OnsiYSI6MSwiayI6W3sidCI6MCwicyI6Wzk2LDk2LDEwMF0sImUiOlsxMDQsMTA0LDEwMF0sImkiOnsieCI6WzAuNjY3XSwieSI6WzFdfSwibyI6eyJ4Ijpb"
    @"MC4zMzNdLCJ5IjpbMF19fSx7InQiOjkwLCJzIjpbMTA0LDEwNCwxMDBdLCJlIjpbOTYsOTYsMTAwXSwiaSI6eyJ4IjpbMC42NjddLCJ5IjpbMV19LCJvIjp7"
    @"IngiOlswLjMzM10sInkiOlswXX19LHsidCI6MTgwLCJzIjpbOTYsOTYsMTAwXX1dfX0sImFvIjowLCJzaGFwZXMiOlt7InR5IjoiZ3IiLCJubSI6IlNwYXJr"
    @"bGUgQSIsIml0IjpbeyJ0eSI6ImVsIiwiZCI6MSwicCI6eyJhIjowLCJrIjpbLTY0LC00Ml19LCJzIjp7ImEiOjAsImsiOlsxOCwxOF19LCJubSI6IkVsbGlw"
    @"c2UgUGF0aCAxIn0seyJ0eSI6ImZsIiwiYyI6eyJhIjowLCJrIjpbMSwwLjc4OCwwLjgzOSwxXX0sIm8iOnsiYSI6MCwiayI6MTAwfSwiciI6MSwiYm0iOjAs"
    @"Im5tIjoiRmlsbCAxIn0seyJ0eSI6InRyIiwicCI6eyJhIjowLCJrIjpbMCwwXX0sImEiOnsiYSI6MCwiayI6WzAsMF19LCJzIjp7ImEiOjAsImsiOlsxMDAs"
    @"MTAwXX0sInIiOnsiYSI6MCwiayI6WzBdfSwibyI6eyJhIjowLCJrIjoxMDB9LCJzayI6eyJhIjowLCJrIjpbMF19LCJzYSI6eyJhIjowLCJrIjpbMF19LCJu"
    @"bSI6IlRyYW5zZm9ybSJ9XX0seyJ0eSI6ImdyIiwibm0iOiJTcGFya2xlIEIiLCJpdCI6W3sidHkiOiJlbCIsImQiOjEsInAiOnsiYSI6MCwiayI6WzY4LC0x"
    @"OF19LCJzIjp7ImEiOjAsImsiOlsxMiwxMl19LCJubSI6IkVsbGlwc2UgUGF0aCAxIn0seyJ0eSI6ImZsIiwiYyI6eyJhIjowLCJrIjpbMC45ODgsMC45ODgs"
    @"MC45OTIsMV19LCJvIjp7ImEiOjAsImsiOjEwMH0sInIiOjEsImJtIjowLCJubSI6IkZpbGwgMSJ9LHsidHkiOiJ0ciIsInAiOnsiYSI6MCwiayI6WzAsMF19"
    @"LCJhIjp7ImEiOjAsImsiOlswLDBdfSwicyI6eyJhIjowLCJrIjpbMTAwLDEwMF19LCJyIjp7ImEiOjAsImsiOlswXX0sIm8iOnsiYSI6MCwiayI6MTAwfSwi"
    @"c2siOnsiYSI6MCwiayI6WzBdfSwic2EiOnsiYSI6MCwiayI6WzBdfSwibm0iOiJUcmFuc2Zvcm0ifV19LHsidHkiOiJnciIsIm5tIjoiU3BhcmtsZSBDIiwi"
    @"aXQiOlt7InR5IjoiZWwiLCJkIjoxLCJwIjp7ImEiOjAsImsiOls0LDcyXX0sInMiOnsiYSI6MCwiayI6WzE2LDE2XX0sIm5tIjoiRWxsaXBzZSBQYXRoIDEi"
    @"fSx7InR5IjoiZmwiLCJjIjp7ImEiOjAsImsiOlswLjk3NiwwLjY1NSwwLjczNywxXX0sIm8iOnsiYSI6MCwiayI6MTAwfSwiciI6MSwiYm0iOjAsIm5tIjoi"
    @"RmlsbCAxIn0seyJ0eSI6InRyIiwicCI6eyJhIjowLCJrIjpbMCwwXX0sImEiOnsiYSI6MCwiayI6WzAsMF19LCJzIjp7ImEiOjAsImsiOlsxMDAsMTAwXX0s"
    @"InIiOnsiYSI6MCwiayI6WzBdfSwibyI6eyJhIjowLCJrIjoxMDB9LCJzayI6eyJhIjowLCJrIjpbMF19LCJzYSI6eyJhIjowLCJrIjpbMF19LCJubSI6IlRy"
    @"YW5zZm9ybSJ9XX1dLCJpcCI6MCwib3AiOjE4MCwic3QiOjAsImJtIjowfSx7ImRkZCI6MCwiaW5kIjo0LCJ0eSI6NCwibm0iOiJWZXQgSWNvbiIsInNyIjox"
    @"LCJrcyI6eyJvIjp7ImEiOjAsImsiOlsxMDBdfSwiciI6eyJhIjoxLCJrIjpbeyJ0IjowLCJzIjpbLTRdLCJlIjpbNF0sImkiOnsieCI6WzAuNjY3XSwieSI6"
    @"WzFdfSwibyI6eyJ4IjpbMC4zMzNdLCJ5IjpbMF19fSx7InQiOjkwLCJzIjpbNF0sImUiOlstNF0sImkiOnsieCI6WzAuNjY3XSwieSI6WzFdfSwibyI6eyJ4"
    @"IjpbMC4zMzNdLCJ5IjpbMF19fSx7InQiOjE4MCwicyI6Wy00XX1dfSwicCI6eyJhIjoxLCJrIjpbeyJ0IjowLCJzIjpbMTI4LDEyOCwwXSwiZSI6WzEyOCwx"
    @"MjIsMF0sImkiOnsieCI6WzAuNjY3XSwieSI6WzFdfSwibyI6eyJ4IjpbMC4zMzNdLCJ5IjpbMF19fSx7InQiOjkwLCJzIjpbMTI4LDEyMiwwXSwiZSI6WzEy"
    @"OCwxMjgsMF0sImkiOnsieCI6WzAuNjY3XSwieSI6WzFdfSwibyI6eyJ4IjpbMC4zMzNdLCJ5IjpbMF19fSx7InQiOjE4MCwicyI6WzEyOCwxMjgsMF19XX0s"
    @"ImEiOnsiYSI6MCwiayI6WzAsMCwwXX0sInMiOnsiYSI6MSwiayI6W3sidCI6MCwicyI6WzkyLDkyLDEwMF0sImUiOlsxMDIsMTAyLDEwMF0sImkiOnsieCI6"
    @"WzAuNjY3XSwieSI6WzFdfSwibyI6eyJ4IjpbMC4zMzNdLCJ5IjpbMF19fSx7InQiOjQ1LCJzIjpbMTAyLDEwMiwxMDBdLCJlIjpbOTYsOTYsMTAwXSwiaSI6"
    @"eyJ4IjpbMC42NjddLCJ5IjpbMV19LCJvIjp7IngiOlswLjMzM10sInkiOlswXX19LHsidCI6OTAsInMiOls5Niw5NiwxMDBdLCJlIjpbMTAyLDEwMiwxMDBd"
    @"LCJpIjp7IngiOlswLjY2N10sInkiOlsxXX0sIm8iOnsieCI6WzAuMzMzXSwieSI6WzBdfX0seyJ0IjoxODAsInMiOls5Miw5MiwxMDBdfV19fSwiYW8iOjAs"
    @"InNoYXBlcyI6W3sidHkiOiJnciIsIm5tIjoiVmVydGljYWwiLCJpdCI6W3sidHkiOiJyYyIsImQiOjEsInAiOnsiYSI6MCwiayI6WzAsMF19LCJzIjp7ImEi"
    @"OjAsImsiOlszNCwxMTBdfSwiciI6eyJhIjowLCJrIjpbMTZdfSwibm0iOiJSZWN0YW5nbGUgUGF0aCAxIn0seyJ0eSI6ImZsIiwiYyI6eyJhIjowLCJrIjpb"
    @"MC45ODgsMC45ODgsMC45OTIsMV19LCJvIjp7ImEiOjAsImsiOjEwMH0sInIiOjEsImJtIjowLCJubSI6IkZpbGwgMSJ9LHsidHkiOiJ0ciIsInAiOnsiYSI6"
    @"MCwiayI6WzAsMF19LCJhIjp7ImEiOjAsImsiOlswLDBdfSwicyI6eyJhIjowLCJrIjpbMTAwLDEwMF19LCJyIjp7ImEiOjAsImsiOlswXX0sIm8iOnsiYSI6"
    @"MCwiayI6MTAwfSwic2siOnsiYSI6MCwiayI6WzBdfSwic2EiOnsiYSI6MCwiayI6WzBdfSwibm0iOiJUcmFuc2Zvcm0ifV19LHsidHkiOiJnciIsIm5tIjoi"
    @"SG9yaXpvbnRhbCIsIml0IjpbeyJ0eSI6InJjIiwiZCI6MSwicCI6eyJhIjowLCJrIjpbMCwwXX0sInMiOnsiYSI6MCwiayI6WzExMCwzNF19LCJyIjp7ImEi"
    @"OjAsImsiOlsxNl19LCJubSI6IlJlY3RhbmdsZSBQYXRoIDEifSx7InR5IjoiZmwiLCJjIjp7ImEiOjAsImsiOlswLjk4OCwwLjk4OCwwLjk5MiwxXX0sIm8i"
    @"OnsiYSI6MCwiayI6MTAwfSwiciI6MSwiYm0iOjAsIm5tIjoiRmlsbCAxIn0seyJ0eSI6InRyIiwicCI6eyJhIjowLCJrIjpbMCwwXX0sImEiOnsiYSI6MCwi"
    @"ayI6WzAsMF19LCJzIjp7ImEiOjAsImsiOlsxMDAsMTAwXX0sInIiOnsiYSI6MCwiayI6WzBdfSwibyI6eyJhIjowLCJrIjoxMDB9LCJzayI6eyJhIjowLCJr"
    @"IjpbMF19LCJzYSI6eyJhIjowLCJrIjpbMF19LCJubSI6IlRyYW5zZm9ybSJ9XX0seyJ0eSI6ImdyIiwibm0iOiJQdWxzZSBEb3QiLCJpdCI6W3sidHkiOiJl"
    @"bCIsImQiOjEsInAiOnsiYSI6MCwiayI6WzQyLC00Ml19LCJzIjp7ImEiOjAsImsiOlsyNCwyNF19LCJubSI6IkVsbGlwc2UgUGF0aCAxIn0seyJ0eSI6ImZs"
    @"IiwiYyI6eyJhIjowLCJrIjpbMSwwLjY5NCwwLjczNywxXX0sIm8iOnsiYSI6MCwiayI6MTAwfSwiciI6MSwiYm0iOjAsIm5tIjoiRmlsbCAxIn0seyJ0eSI6"
    @"InRyIiwicCI6eyJhIjowLCJrIjpbMCwwXX0sImEiOnsiYSI6MCwiayI6WzAsMF19LCJzIjp7ImEiOjEsImsiOlt7InQiOjAsInMiOls3MCw3MF0sImUiOlsx"
    @"MTYsMTE2XSwiaSI6eyJ4IjpbMC42NjddLCJ5IjpbMV19LCJvIjp7IngiOlswLjMzM10sInkiOlswXX19LHsidCI6NDUsInMiOlsxMTYsMTE2XSwiZSI6Wzg4"
    @"LDg4XSwiaSI6eyJ4IjpbMC42NjddLCJ5IjpbMV19LCJvIjp7IngiOlswLjMzM10sInkiOlswXX19LHsidCI6OTAsInMiOls4OCw4OF0sImUiOlsxMTYsMTE2"
    @"XSwiaSI6eyJ4IjpbMC42NjddLCJ5IjpbMV19LCJvIjp7IngiOlswLjMzM10sInkiOlswXX19LHsidCI6MTgwLCJzIjpbNzAsNzBdfV19LCJyIjp7ImEiOjAs"
    @"ImsiOlswXX0sIm8iOnsiYSI6MSwiayI6W3sidCI6MCwicyI6WzcyXSwiZSI6WzEwMF0sImkiOnsieCI6WzAuNjY3XSwieSI6WzFdfSwibyI6eyJ4IjpbMC4z"
    @"MzNdLCJ5IjpbMF19fSx7InQiOjQ1LCJzIjpbMTAwXSwiZSI6Wzc4XSwiaSI6eyJ4IjpbMC42NjddLCJ5IjpbMV19LCJvIjp7IngiOlswLjMzM10sInkiOlsw"
    @"XX19LHsidCI6OTAsInMiOls3OF0sImUiOlsxMDBdLCJpIjp7IngiOlswLjY2N10sInkiOlsxXX0sIm8iOnsieCI6WzAuMzMzXSwieSI6WzBdfX0seyJ0Ijox"
    @"ODAsInMiOls3Ml19XX0sInNrIjp7ImEiOjAsImsiOlswXX0sInNhIjp7ImEiOjAsImsiOlswXX0sIm5tIjoiVHJhbnNmb3JtIn1dfV0sImlwIjowLCJvcCI6"
    @"MTgwLCJzdCI6MCwiYm0iOjB9XX0=";
}

static LOTComposition *PPPetCarePremiumCompositionFromBase64(NSString *base64)
{
    if (base64.length == 0) {
        return nil;
    }

    NSData *data = [[NSData alloc] initWithBase64EncodedString:base64 options:0];
    if (data.length == 0) {
        return nil;
    }

    NSError *jsonError = nil;
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&jsonError];
    if (jsonError || ![json isKindOfClass:[NSDictionary class]]) {
        return nil;
    }

    return [LOTComposition animationFromJSON:json];
}

static LOTComposition *PPPetCarePremiumHeroComposition(PPPetCareInitialSection section)
{
    static LOTComposition *medicineComposition = nil;
    static LOTComposition *vetComposition = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        medicineComposition = PPPetCarePremiumCompositionFromBase64(PPPetCarePremiumMedicineHeroAnimationBase64());
        vetComposition = PPPetCarePremiumCompositionFromBase64(PPPetCarePremiumVetHeroAnimationBase64());
    });

    return section == PPPetCareInitialSectionVeterinarians ? vetComposition : medicineComposition;
}




@interface PPPetCareViewController () <UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UITextFieldDelegate, PPUniversalCellDelegate>
@property (nonatomic, assign) PPPetCareInitialSection selectedSection;
@property (nonatomic, assign) PPPetCareMedicineFilter medicineFilter;
@property (nonatomic, assign) PPPetCareVetFilter vetFilter;
@property (nonatomic, strong, nullable) MainKindsModel *selectedMainKind;
@property (nonatomic, copy) NSArray<MainKindsModel *> *mainKinds;
@property (nonatomic, copy) NSArray<VetMedicineModel *> *allMedicines;
@property (nonatomic, copy) NSArray<VetMedicineModel *> *filteredMedicines;
@property (nonatomic, copy) NSArray<VetModel *> *allVets;
@property (nonatomic, copy) NSArray<VetModel *> *filteredVets;
@property (nonatomic, strong) UIView *heroView;
@property (nonatomic, strong) UIView *heroFill;
@property (nonatomic, strong) CAGradientLayer *heroGradientLayer;
@property (nonatomic, strong) UIView *backgroundGlowTopView;
@property (nonatomic, strong) UIView *backgroundGlowMiddleView;
@property (nonatomic, strong) UIView *backgroundGlowBottomView;
@property (nonatomic, strong) UIView *largeOrbView;
@property (nonatomic, strong) UIView *smallOrbView;
@property (nonatomic, strong) UIView *iconPlateView;
@property (nonatomic, strong) UIImageView *heroIconView;
@property (nonatomic, strong) LOTAnimationView *heroAnimationView;
@property (nonatomic, strong) UILabel *eyebrowLabel;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UILabel *counterLabel;
@property (nonatomic, strong) UISegmentedControl *sectionControl;
@property (nonatomic, strong) UIView *sectionTitleContainer;
@property (nonatomic, strong, nullable) UIButton *navCartButton;
@property (nonatomic, strong) UIView *bottomSearchBarView;
@property (nonatomic, strong) UIView *bottomSearchFadeView;
@property (nonatomic, strong) CAGradientLayer *bottomSearchFadeLayer;
@property (nonatomic, strong) UIView *searchPillView;
@property (nonatomic, strong) UITextField *searchField;
@property (nonatomic, strong) UIImageView *searchIconView;
@property (nonatomic, strong) UIButton *filterButton;
@property (nonatomic, strong) UIView *filterBadgeView;
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) UIView *emptyView;
@property (nonatomic, strong) UILabel *emptyTitleLabel;
@property (nonatomic, strong) UILabel *emptySubtitleLabel;
@property (nonatomic, copy) NSString *selectedMedicineID;
@property (nonatomic, strong) NSLayoutConstraint *bottomSearchBarBottomConstraint;
@property (nonatomic, assign) BOOL loadingMedicines;
@property (nonatomic, assign) BOOL loadingVets;
@property (nonatomic, assign) CGFloat keyboardOverlap;
@property (nonatomic, assign) BOOL previousIQKeyboardManagerEnabled;
@property (nonatomic, assign) BOOL previousIQKeyboardToolbarEnabled;
@property (nonatomic, assign) BOOL isOverridingIQKeyboardManager;
@property (nonatomic, copy) NSString *currentHeroAnimationName;
@property (nonatomic, assign) NSInteger heroAnimationLoadToken;
@property (nonatomic, assign) BOOL didAnimateEntrance;
@property (nonatomic, assign) BOOL didStartGlowAnimation;
@property (nonatomic, assign) BOOL didFinishInitialDataLoad;
@property (nonatomic, assign) BOOL didRevealLoadedDecor;
- (void)pp_buildBackgroundAtmosphereInView:(UIView *)hostView;
- (UIView *)pp_backgroundGlowViewWithRadius:(CGFloat)radius;
- (void)pp_prepareEntranceState;
- (void)pp_beginEntranceAnimationIfNeeded;
- (void)pp_beginAmbientGlowAnimationIfNeeded;
- (void)pp_stopAmbientGlowAnimation;
- (void)pp_noteInitialDataLoadProgress;
- (void)pp_revealLoadedDecorIfNeeded;
- (void)pp_configureHeroAnimationIfNeeded;
- (void)pp_revealResolvedHeroAnimation;
- (void)pp_styleNavigationSectionControl;
- (void)pp_installCartNavigationButton;
- (void)pp_updateCartBadge;
- (void)pp_applyFilterButtonAppearance;
- (void)pp_applyKeyboardManagerOverridesIfNeeded;
- (void)pp_restoreKeyboardManagerOverridesIfNeeded;
- (void)pp_presentMedicineDetails:(VetMedicineModel *)medicine;
- (void)pp_presentVetDetails:(VetModel *)vet;
- (void)pp_openPetCareViewer:(UIViewController *)viewer;
- (void)pp_selectMedicine:(VetMedicineModel *)medicine;
- (void)pp_reloadMedicineCellForViewModel:(PPUniversalCellViewModel *)vm;
- (void)pp_reloadVisibleMedicineCells;
- (BOOL)pp_ensureSignedInForAction;
- (PPUniversalCellViewModel *)pp_universalViewModelForMedicine:(VetMedicineModel *)medicine
                                                   mainKindName:(NSString *)mainKindName
                                                     indexPath:(NSIndexPath *)indexPath;
@end



@implementation PPPetCareViewController

- (instancetype)initWithInitialSection:(PPPetCareInitialSection)section
                              mainKind:(MainKindsModel *)mainKind
{
    self = [super initWithNibName:nil bundle:nil];
    if (!self) {
        return nil;
    }
    _selectedSection = section;
    _selectedMainKind = mainKind;
    _medicineFilter = PPPetCareMedicineFilterAll;
    _vetFilter = PPPetCareVetFilterAll;
    _mainKinds = @[];
    _allMedicines = @[];
    _filteredMedicines = @[];
    _allVets = @[];
    _filteredVets = @[];
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self pp_applyKeyboardManagerOverridesIfNeeded];
    self.view.backgroundColor = AppBackgroundClr;
    [self pp_navBarApplyBase:PPNavBarBaseLayoutAuto
                      button:nil
                       title:nil//PPPetCareLocalized(@"pet_care_title", @"Pet Care")
                    showBack:YES];
    [self pp_setupViews];
    [self pp_installCartNavigationButton];
    [self pp_loadFilters];
    [self pp_updateLocalizedText];
    [self pp_applyTheme];
    [self pp_prepareEntranceState];
    [self pp_loadData];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pp_appWillEnterForeground)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pp_keyboardWillChangeFrame:)
                                                 name:UIKeyboardWillChangeFrameNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pp_keyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pp_handleCartUpdated:)
                                                 name:kCartUpdatedNotification
                                               object:nil];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self pp_beginEntranceAnimationIfNeeded];
    BOOL hadRevealedLoadedDecor = self.didRevealLoadedDecor;
    [self pp_revealLoadedDecorIfNeeded];
    if (hadRevealedLoadedDecor || !self.didFinishInitialDataLoad) {
        [self pp_configureHeroAnimationIfNeeded];
    }
    if (self.didRevealLoadedDecor) {
        [self pp_beginAmbientGlowAnimationIfNeeded];
    }
}

- (void)dealloc
{
    [self pp_restoreKeyboardManagerOverridesIfNeeded];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    if ([self.tabBarController respondsToSelector:@selector(setPremiumTabDockViewHidden:animation:)]) {
        [(PPRootTabBarController *)self.tabBarController setPremiumTabDockViewHidden:YES animation:animated];
    }

    if (!PPIOS26()) {
        UIView *dimView = [self.view viewWithTag:8726];
        [UIView animateWithDuration:0.18
                              delay:0.0
                            options:UIViewAnimationOptionCurveEaseIn
                         animations:^{
            dimView.backgroundColor = [UIColor.blackColor colorWithAlphaComponent:0.0];
        } completion:^(BOOL finished) {
            [dimView removeFromSuperview];
        }];
    }

    [self pp_applyKeyboardManagerOverridesIfNeeded];
    [self pp_installNavigationTitleControl];
    [self pp_installCartNavigationButton];
    [self pp_updateLocalizedText];
    [self pp_applyTheme];
    [self pp_updateCartBadge];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self.searchField resignFirstResponder];
    [self.heroAnimationView stop];
    [self pp_stopAmbientGlowAnimation];
    [self pp_restoreKeyboardManagerOverridesIfNeeded];
    if ((self.isMovingFromParentViewController || self.isBeingDismissed) &&
        [self.tabBarController respondsToSelector:@selector(setPremiumTabDockViewHidden:animation:)]) {
        [(PPRootTabBarController *)self.tabBarController setPremiumTabDockViewHidden:NO animation:animated];
    }
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            [self pp_applyTheme];
            [self.collectionView reloadData];
        }
    }
}

- (void)pp_appWillEnterForeground
{
    [self pp_applyTheme];
    [self pp_updateBottomSearchPositionAnimated:NO notification:nil];
    [self pp_updateCollectionBottomInsets];
    [self.collectionView.visibleCells makeObjectsPerformSelector:@selector(setNeedsLayout)];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    if (self.heroGradientLayer && self.heroFill) {
        self.heroGradientLayer.frame = self.heroFill.bounds;
        self.heroGradientLayer.cornerRadius = self.heroFill.layer.cornerRadius;
    }
    if (self.heroView) {
        self.heroView.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.heroView.bounds cornerRadius:self.heroView.layer.cornerRadius].CGPath;
    }
    if (self.bottomSearchFadeLayer && self.bottomSearchFadeView) {
        self.bottomSearchFadeLayer.frame = self.bottomSearchFadeView.bounds;
    }
    for (UIView *glowView in @[self.backgroundGlowTopView,
                               self.backgroundGlowMiddleView,
                               self.backgroundGlowBottomView]) {
        if (CGRectIsEmpty(glowView.bounds)) {
            continue;
        }
        glowView.layer.cornerRadius = CGRectGetWidth(glowView.bounds) * 0.5;
        glowView.layer.shadowPath = [UIBezierPath bezierPathWithOvalInRect:glowView.bounds].CGPath;
    }
    [self pp_updateBottomSearchPositionAnimated:NO notification:nil];
    [self pp_updateCollectionBottomInsets];
}

#pragma mark - Setup

- (void)pp_setupViews
{
    UIView *contentView = [[UIView alloc] init];
    contentView.translatesAutoresizingMaskIntoConstraints = NO;
    contentView.backgroundColor = UIColor.clearColor;
    [self.view addSubview:contentView];
    [self pp_buildBackgroundAtmosphereInView:contentView];

    _heroView = [[UIView alloc] init];
    _heroView.translatesAutoresizingMaskIntoConstraints = NO;
    _heroView.layer.cornerRadius = 32.0;
    _heroView.layer.borderWidth = 0.8;
    _heroView.clipsToBounds = NO;
    if (@available(iOS 13.0, *)) {
        _heroView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [_heroView pp_setShadowColor:[UIColor colorWithWhite:0.0 alpha:1.0]];
    _heroView.layer.shadowRadius = 24.0;
    _heroView.layer.shadowOffset = CGSizeMake(0.0, 12.0);
    [contentView addSubview:_heroView];

    _heroFill = [[UIView alloc] init];
    _heroFill.translatesAutoresizingMaskIntoConstraints = NO;
    _heroFill.layer.cornerRadius = 32.0;
    _heroFill.clipsToBounds = YES;
    if (@available(iOS 13.0, *)) {
        _heroFill.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [_heroView addSubview:_heroFill];

    _heroGradientLayer = [CAGradientLayer layer];
    _heroGradientLayer.startPoint = CGPointMake(0.0, 0.0);
    _heroGradientLayer.endPoint = CGPointMake(1.0, 1.0);
    [_heroFill.layer insertSublayer:_heroGradientLayer atIndex:0];

    _largeOrbView = [[UIView alloc] init];
    _largeOrbView.translatesAutoresizingMaskIntoConstraints = NO;
    _largeOrbView.layer.cornerRadius = 60.0;
    [_heroFill addSubview:_largeOrbView];

    _smallOrbView = [[UIView alloc] init];
    _smallOrbView.translatesAutoresizingMaskIntoConstraints = NO;
    _smallOrbView.layer.cornerRadius = 24.0;
    [_heroFill addSubview:_smallOrbView];

    _iconPlateView = [[UIView alloc] init];
    _iconPlateView.translatesAutoresizingMaskIntoConstraints = NO;
    _iconPlateView.layer.cornerRadius = 24.0;
    _iconPlateView.layer.borderWidth = 0.8;
    if (@available(iOS 13.0, *)) {
        _iconPlateView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [_heroView addSubview:_iconPlateView];

    _heroIconView = [[UIImageView alloc] initWithImage:[[UIImage systemImageNamed:@"cross.case.fill"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]];
    _heroIconView.translatesAutoresizingMaskIntoConstraints = NO;
    _heroIconView.contentMode = UIViewContentModeScaleAspectFit;
    [_iconPlateView addSubview:_heroIconView];

    _heroAnimationView = [[LOTAnimationView alloc] init];
    _heroAnimationView.translatesAutoresizingMaskIntoConstraints = NO;
    _heroAnimationView.contentMode = UIViewContentModeScaleAspectFit;
    _heroAnimationView.loopAnimation = YES;
    _heroAnimationView.animationSpeed = 0.84;
    _heroAnimationView.userInteractionEnabled = NO;
    _heroAnimationView.hidden = YES;
    _heroAnimationView.alpha = 0.0;
    [_iconPlateView addSubview:_heroAnimationView];

    _eyebrowLabel = [[UILabel alloc] init];
    _eyebrowLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _eyebrowLabel.font = [GM boldFontWithSize:11.0] ?: [UIFont systemFontOfSize:11.0 weight:UIFontWeightSemibold];
    _eyebrowLabel.numberOfLines = 1;
    [_heroView addSubview:_eyebrowLabel];

    _titleLabel = [[UILabel alloc] init];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.font = [GM boldFontWithSize:26.0] ?: [UIFont systemFontOfSize:26.0 weight:UIFontWeightBold];
    _titleLabel.numberOfLines = 1;
    _titleLabel.adjustsFontSizeToFitWidth = YES;
    _titleLabel.minimumScaleFactor = 0.78;
    [_heroView addSubview:_titleLabel];

    _subtitleLabel = [[UILabel alloc] init];
    _subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _subtitleLabel.font = [GM MidFontWithSize:14.0] ?: [UIFont systemFontOfSize:14.0 weight:UIFontWeightMedium];
    _subtitleLabel.numberOfLines = 2;
    [_heroView addSubview:_subtitleLabel];

    _counterLabel = [[UILabel alloc] init];
    _counterLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _counterLabel.font = [GM boldFontWithSize:12.0] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightSemibold];
    _counterLabel.textAlignment = NSTextAlignmentCenter;
    _counterLabel.layer.cornerRadius = 14.0;
    _counterLabel.layer.masksToBounds = YES;
    _counterLabel.layer.borderWidth = 0.8;
    if (@available(iOS 13.0, *)) {
        _counterLabel.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [_heroView addSubview:_counterLabel];

    _sectionControl = [[UISegmentedControl alloc] initWithItems:@[@"", @""]];
    _sectionControl.translatesAutoresizingMaskIntoConstraints = NO;
    _sectionControl.selectedSegmentIndex = self.selectedSection == PPPetCareInitialSectionVeterinarians ? 1 : 0;
    [_sectionControl addTarget:self action:@selector(pp_sectionChanged:) forControlEvents:UIControlEventValueChanged];
    [self pp_installNavigationTitleControl];

    _bottomSearchBarView = [[UIView alloc] init];
    _bottomSearchBarView.translatesAutoresizingMaskIntoConstraints = NO;
    _bottomSearchBarView.backgroundColor = UIColor.clearColor;
    _bottomSearchBarView.layer.shadowRadius = 22.0;
    _bottomSearchBarView.layer.shadowOffset = CGSizeMake(0.0, 8.0);
    _bottomSearchBarView.layer.shadowOpacity = 0.14;
    [_bottomSearchBarView pp_setShadowColor:[UIColor colorWithWhite:0.0 alpha:1.0]];
    [contentView addSubview:_bottomSearchBarView];

    _bottomSearchFadeView = [[UIView alloc] init];
    _bottomSearchFadeView.translatesAutoresizingMaskIntoConstraints = NO;
    _bottomSearchFadeView.backgroundColor = UIColor.clearColor;
    _bottomSearchFadeView.userInteractionEnabled = NO;
    [contentView addSubview:_bottomSearchFadeView];

    _bottomSearchFadeLayer = [CAGradientLayer layer];
    _bottomSearchFadeLayer.startPoint = CGPointMake(0.5, 0.0);
    _bottomSearchFadeLayer.endPoint = CGPointMake(0.5, 1.0);
    [_bottomSearchFadeView.layer addSublayer:_bottomSearchFadeLayer];

    _searchPillView = [[UIView alloc] init];
    _searchPillView.translatesAutoresizingMaskIntoConstraints = NO;
    _searchPillView.layer.cornerRadius = 28.0;
    _searchPillView.layer.borderWidth = 0.7;
    _searchPillView.clipsToBounds = YES;
    if (@available(iOS 13.0, *)) {
        _searchPillView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [_bottomSearchBarView addSubview:_searchPillView];

    if (@available(iOS 13.0, *)) {
        UIVisualEffectView *searchMaterial =
            [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial]];
        searchMaterial.translatesAutoresizingMaskIntoConstraints = NO;
        searchMaterial.userInteractionEnabled = NO;
        [_searchPillView addSubview:searchMaterial];
        [NSLayoutConstraint activateConstraints:@[
            [searchMaterial.topAnchor constraintEqualToAnchor:_searchPillView.topAnchor],
            [searchMaterial.leadingAnchor constraintEqualToAnchor:_searchPillView.leadingAnchor],
            [searchMaterial.trailingAnchor constraintEqualToAnchor:_searchPillView.trailingAnchor],
            [searchMaterial.bottomAnchor constraintEqualToAnchor:_searchPillView.bottomAnchor]
        ]];
    }

    _searchField = [[UITextField alloc] init];
    _searchField.translatesAutoresizingMaskIntoConstraints = NO;
    _searchField.delegate = self;
    _searchField.clearButtonMode = UITextFieldViewModeWhileEditing;
    _searchField.returnKeyType = UIReturnKeySearch;
    _searchField.backgroundColor = UIColor.clearColor;
    _searchField.leftViewMode = UITextFieldViewModeNever;
    _searchField.inputAccessoryView = nil;
    if (@available(iOS 9.0, *)) {
        _searchField.inputAssistantItem.leadingBarButtonGroups = @[];
        _searchField.inputAssistantItem.trailingBarButtonGroups = @[];
    }
    _searchField.font = [GM MidFontWithSize:17.0] ?: [UIFont systemFontOfSize:17.0 weight:UIFontWeightRegular];
    [_searchField addTarget:self action:@selector(pp_searchTextChanged:) forControlEvents:UIControlEventEditingChanged];
    [_searchPillView addSubview:_searchField];

    _searchIconView = [[UIImageView alloc] initWithImage:[[UIImage systemImageNamed:@"magnifyingglass"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]];
    _searchIconView.translatesAutoresizingMaskIntoConstraints = NO;
    _searchIconView.tintColor = PPPetCareSecondaryTextColor();
    _searchIconView.contentMode = UIViewContentModeScaleAspectFit;
    _searchIconView.isAccessibilityElement = NO;
    [_searchPillView addSubview:_searchIconView];

    _filterButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _filterButton.translatesAutoresizingMaskIntoConstraints = NO;
    _filterButton.layer.cornerRadius = 30.0;
    _filterButton.layer.borderWidth = 1.0;
    _filterButton.clipsToBounds = NO;
    if (@available(iOS 13.0, *)) {
        _filterButton.layer.cornerCurve = kCACornerCurveContinuous;
    }
    _filterButton.accessibilityLabel = PPPetCareLocalized(@"pet_care_filter_by", @"Filter By");
    if (@available(iOS 14.0, *)) {
        _filterButton.showsMenuAsPrimaryAction = YES;
    }
    [self pp_applyFilterButtonAppearance];
    [_bottomSearchBarView addSubview:_filterButton];

    _filterBadgeView = [[UIView alloc] init];
    _filterBadgeView.translatesAutoresizingMaskIntoConstraints = NO;
    _filterBadgeView.backgroundColor = [UIColor systemRedColor];
    _filterBadgeView.layer.cornerRadius = 4.5;
    _filterBadgeView.layer.masksToBounds = YES;
    _filterBadgeView.layer.borderWidth = 1.5;
    _filterBadgeView.layer.borderColor = UIColor.whiteColor.CGColor;
    _filterBadgeView.hidden = YES;
    _filterBadgeView.userInteractionEnabled = NO;
    [_filterButton addSubview:_filterBadgeView];

    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.minimumLineSpacing = 12.0;
    layout.minimumInteritemSpacing = 12.0;
    layout.sectionInset = UIEdgeInsetsMake(6.0, 18.0, 24.0, 18.0);

    _collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    _collectionView.translatesAutoresizingMaskIntoConstraints = NO;
    _collectionView.backgroundColor = AppClearClr;
    _collectionView.dataSource = self;
    _collectionView.delegate = self;
    _collectionView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    [PPUniversalCell pp_registerInCollectionView:self.collectionView];
    [_collectionView registerClass:PPPetCareVetCell.class forCellWithReuseIdentifier:PPPetCareVetCell.reuseIdentifier];
    [contentView addSubview:_collectionView];

    _emptyView = [[UIView alloc] init];
    _emptyView.translatesAutoresizingMaskIntoConstraints = NO;
    _emptyView.userInteractionEnabled = NO;
    _emptyView.hidden = YES;

    UIImageView *emptyIcon = [[UIImageView alloc] initWithImage:[[UIImage systemImageNamed:@"heart.text.square.fill"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]];
    emptyIcon.translatesAutoresizingMaskIntoConstraints = NO;
    emptyIcon.tintColor = [PPPetCareAccentColor() colorWithAlphaComponent:0.72];
    [_emptyView addSubview:emptyIcon];

    _emptyTitleLabel = [[UILabel alloc] init];
    _emptyTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _emptyTitleLabel.font = [GM boldFontWithSize:18.0] ?: [UIFont systemFontOfSize:18.0 weight:UIFontWeightSemibold];
    _emptyTitleLabel.textColor = PPPetCareTextColor();
    _emptyTitleLabel.textAlignment = NSTextAlignmentCenter;
    _emptyTitleLabel.numberOfLines = 2;
    [_emptyView addSubview:_emptyTitleLabel];

    _emptySubtitleLabel = [[UILabel alloc] init];
    _emptySubtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _emptySubtitleLabel.font = [GM MidFontWithSize:13.0] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightMedium];
    _emptySubtitleLabel.textColor = PPPetCareSecondaryTextColor();
    _emptySubtitleLabel.textAlignment = NSTextAlignmentCenter;
    _emptySubtitleLabel.numberOfLines = 3;
    [_emptyView addSubview:_emptySubtitleLabel];
    [contentView addSubview:_emptyView];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    self.bottomSearchBarBottomConstraint =
        [_bottomSearchBarView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:0.0];

    [NSLayoutConstraint activateConstraints:@[
        [contentView.topAnchor constraintEqualToAnchor:safe.topAnchor],
        [contentView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [contentView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [contentView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [_heroFill.topAnchor constraintEqualToAnchor:_heroView.topAnchor],
        [_heroFill.leadingAnchor constraintEqualToAnchor:_heroView.leadingAnchor],
        [_heroFill.trailingAnchor constraintEqualToAnchor:_heroView.trailingAnchor],
        [_heroFill.bottomAnchor constraintEqualToAnchor:_heroView.bottomAnchor],

        [_heroView.topAnchor constraintEqualToAnchor:contentView.topAnchor constant:12.0],
        [_heroView.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:18.0],
        [_heroView.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-18.0],
        [_heroView.heightAnchor constraintEqualToConstant:172.0],

        [_largeOrbView.widthAnchor constraintEqualToConstant:120.0],
        [_largeOrbView.heightAnchor constraintEqualToConstant:120.0],
        [_largeOrbView.trailingAnchor constraintEqualToAnchor:_heroFill.trailingAnchor constant:24.0],
        [_largeOrbView.topAnchor constraintEqualToAnchor:_heroFill.topAnchor constant:-24.0],

        [_smallOrbView.widthAnchor constraintEqualToConstant:48.0],
        [_smallOrbView.heightAnchor constraintEqualToConstant:48.0],
        [_smallOrbView.leadingAnchor constraintEqualToAnchor:_heroFill.leadingAnchor constant:30.0],
        [_smallOrbView.bottomAnchor constraintEqualToAnchor:_heroFill.bottomAnchor constant:16.0],

        [_iconPlateView.trailingAnchor constraintEqualToAnchor:_heroView.trailingAnchor constant:-18.0],
        [_iconPlateView.topAnchor constraintEqualToAnchor:_heroView.topAnchor constant:18.0],
        [_iconPlateView.widthAnchor constraintEqualToConstant:48.0],
        [_iconPlateView.heightAnchor constraintEqualToConstant:48.0],

        [_heroIconView.centerXAnchor constraintEqualToAnchor:_iconPlateView.centerXAnchor],
        [_heroIconView.centerYAnchor constraintEqualToAnchor:_iconPlateView.centerYAnchor],
        [_heroIconView.widthAnchor constraintEqualToConstant:22.0],
        [_heroIconView.heightAnchor constraintEqualToConstant:22.0],

        [_heroAnimationView.centerXAnchor constraintEqualToAnchor:_iconPlateView.centerXAnchor],
        [_heroAnimationView.centerYAnchor constraintEqualToAnchor:_iconPlateView.centerYAnchor],
        [_heroAnimationView.widthAnchor constraintEqualToConstant:88.0],
        [_heroAnimationView.heightAnchor constraintEqualToConstant:88.0],

        [_eyebrowLabel.leadingAnchor constraintEqualToAnchor:_heroView.leadingAnchor constant:20.0],
        [_eyebrowLabel.topAnchor constraintEqualToAnchor:_heroView.topAnchor constant:18.0],
        [_eyebrowLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_iconPlateView.leadingAnchor constant:-12.0],

        [_titleLabel.leadingAnchor constraintEqualToAnchor:_eyebrowLabel.leadingAnchor],
        [_titleLabel.trailingAnchor constraintEqualToAnchor:_iconPlateView.leadingAnchor constant:-12.0],
        [_titleLabel.topAnchor constraintEqualToAnchor:_eyebrowLabel.bottomAnchor constant:8.0],

        [_subtitleLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
        [_subtitleLabel.trailingAnchor constraintEqualToAnchor:_heroView.trailingAnchor constant:-20.0],
        [_subtitleLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:6.0],

        [_counterLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
        [_counterLabel.topAnchor constraintEqualToAnchor:_subtitleLabel.bottomAnchor constant:12.0],
        [_counterLabel.heightAnchor constraintEqualToConstant:28.0],
        [_counterLabel.widthAnchor constraintGreaterThanOrEqualToConstant:76.0],

        [_collectionView.topAnchor constraintEqualToAnchor:_heroView.bottomAnchor constant:14.0],
        [_collectionView.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor],
        [_collectionView.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor],
        [_collectionView.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor],

        [_bottomSearchBarView.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:18.0],
        [_bottomSearchBarView.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-18.0],
        self.bottomSearchBarBottomConstraint,
        [_bottomSearchBarView.heightAnchor constraintEqualToConstant:64.0],

        [_bottomSearchFadeView.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor],
        [_bottomSearchFadeView.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor],
        [_bottomSearchFadeView.topAnchor constraintEqualToAnchor:_bottomSearchBarView.topAnchor constant:16.0],
        [_bottomSearchFadeView.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor],

        [_searchPillView.leadingAnchor constraintEqualToAnchor:_bottomSearchBarView.leadingAnchor],
        [_searchPillView.centerYAnchor constraintEqualToAnchor:_bottomSearchBarView.centerYAnchor],
        [_searchPillView.heightAnchor constraintEqualToConstant:56.0],

        [_filterButton.leadingAnchor constraintEqualToAnchor:_searchPillView.trailingAnchor constant:10.0],
        [_filterButton.trailingAnchor constraintEqualToAnchor:_bottomSearchBarView.trailingAnchor],
        [_filterButton.centerYAnchor constraintEqualToAnchor:_bottomSearchBarView.centerYAnchor],
        [_filterButton.heightAnchor constraintEqualToConstant:56.0],
        [_filterButton.widthAnchor constraintEqualToConstant:56.0],

        [_filterBadgeView.topAnchor constraintEqualToAnchor:_filterButton.topAnchor constant:14.0],
        [_filterBadgeView.trailingAnchor constraintEqualToAnchor:_filterButton.trailingAnchor constant:-14.0],
        [_filterBadgeView.widthAnchor constraintEqualToConstant:9.0],
        [_filterBadgeView.heightAnchor constraintEqualToConstant:9.0],

        [_searchField.topAnchor constraintEqualToAnchor:_searchPillView.topAnchor],
        [_searchField.leadingAnchor constraintEqualToAnchor:_searchPillView.leadingAnchor constant:18.0],
        [_searchField.trailingAnchor constraintEqualToAnchor:_searchIconView.leadingAnchor constant:-10.0],
        [_searchField.bottomAnchor constraintEqualToAnchor:_searchPillView.bottomAnchor],

        [_searchIconView.trailingAnchor constraintEqualToAnchor:_searchPillView.trailingAnchor constant:-18.0],
        [_searchIconView.centerYAnchor constraintEqualToAnchor:_searchPillView.centerYAnchor],
        [_searchIconView.widthAnchor constraintEqualToConstant:20.0],
        [_searchIconView.heightAnchor constraintEqualToConstant:20.0],

        [_emptyView.centerXAnchor constraintEqualToAnchor:_collectionView.centerXAnchor],
        [_emptyView.centerYAnchor constraintEqualToAnchor:_collectionView.centerYAnchor constant:-20.0],
        [_emptyView.leadingAnchor constraintGreaterThanOrEqualToAnchor:_collectionView.leadingAnchor constant:36.0],
        [_emptyView.trailingAnchor constraintLessThanOrEqualToAnchor:_collectionView.trailingAnchor constant:-36.0],

        [emptyIcon.topAnchor constraintEqualToAnchor:_emptyView.topAnchor],
        [emptyIcon.centerXAnchor constraintEqualToAnchor:_emptyView.centerXAnchor],
        [emptyIcon.widthAnchor constraintEqualToConstant:38.0],
        [emptyIcon.heightAnchor constraintEqualToConstant:38.0],

        [_emptyTitleLabel.topAnchor constraintEqualToAnchor:emptyIcon.bottomAnchor constant:12.0],
        [_emptyTitleLabel.leadingAnchor constraintEqualToAnchor:_emptyView.leadingAnchor],
        [_emptyTitleLabel.trailingAnchor constraintEqualToAnchor:_emptyView.trailingAnchor],

        [_emptySubtitleLabel.topAnchor constraintEqualToAnchor:_emptyTitleLabel.bottomAnchor constant:7.0],
        [_emptySubtitleLabel.leadingAnchor constraintEqualToAnchor:_emptyView.leadingAnchor],
        [_emptySubtitleLabel.trailingAnchor constraintEqualToAnchor:_emptyView.trailingAnchor],
        [_emptySubtitleLabel.bottomAnchor constraintEqualToAnchor:_emptyView.bottomAnchor],
    ]];

    [contentView bringSubviewToFront:_bottomSearchFadeView];
    [contentView bringSubviewToFront:_bottomSearchBarView];
    [self pp_updateBottomSearchPositionAnimated:NO notification:nil];
    [self pp_updateCollectionBottomInsets];
}

- (void)pp_buildBackgroundAtmosphereInView:(UIView *)hostView
{
    self.backgroundGlowTopView = [self pp_backgroundGlowViewWithRadius:136.0];
    self.backgroundGlowMiddleView = [self pp_backgroundGlowViewWithRadius:108.0];
    self.backgroundGlowBottomView = [self pp_backgroundGlowViewWithRadius:172.0];

    [hostView addSubview:self.backgroundGlowTopView];
    [hostView addSubview:self.backgroundGlowMiddleView];
    [hostView addSubview:self.backgroundGlowBottomView];

    [NSLayoutConstraint activateConstraints:@[
        [self.backgroundGlowTopView.widthAnchor constraintEqualToConstant:272.0],
        [self.backgroundGlowTopView.heightAnchor constraintEqualToConstant:272.0],
        [self.backgroundGlowTopView.topAnchor constraintEqualToAnchor:hostView.topAnchor constant:-82.0],
        [self.backgroundGlowTopView.trailingAnchor constraintEqualToAnchor:hostView.trailingAnchor constant:104.0],

        [self.backgroundGlowMiddleView.widthAnchor constraintEqualToConstant:216.0],
        [self.backgroundGlowMiddleView.heightAnchor constraintEqualToConstant:216.0],
        [self.backgroundGlowMiddleView.topAnchor constraintEqualToAnchor:hostView.topAnchor constant:248.0],
        [self.backgroundGlowMiddleView.leadingAnchor constraintEqualToAnchor:hostView.leadingAnchor constant:-96.0],

        [self.backgroundGlowBottomView.widthAnchor constraintEqualToConstant:344.0],
        [self.backgroundGlowBottomView.heightAnchor constraintEqualToConstant:344.0],
        [self.backgroundGlowBottomView.leadingAnchor constraintEqualToAnchor:hostView.leadingAnchor constant:-136.0],
        [self.backgroundGlowBottomView.bottomAnchor constraintEqualToAnchor:hostView.bottomAnchor constant:132.0]
    ]];
}

- (UIView *)pp_backgroundGlowViewWithRadius:(CGFloat)radius
{
    UIView *view = [[UIView alloc] init];
    view.translatesAutoresizingMaskIntoConstraints = NO;
    view.userInteractionEnabled = NO;
    view.clipsToBounds = NO;
    view.alpha = 0.0;
    view.hidden = YES;
    view.layer.cornerRadius = radius;
    view.layer.shadowRadius = 68.0;
    view.layer.shadowOpacity = 0.28;
    view.layer.shadowOffset = CGSizeZero;
    return view;
}

#pragma mark - Motion

- (void)pp_prepareEntranceState
{
    NSArray<UIView *> *floatingViews = @[self.backgroundGlowTopView,
                                         self.backgroundGlowMiddleView,
                                         self.backgroundGlowBottomView];
    for (UIView *view in floatingViews) {
        view.alpha = 0.0;
        view.hidden = YES;
        view.transform = CGAffineTransformMakeScale(0.92, 0.92);
    }

    NSArray<UIView *> *headlineViews = @[self.iconPlateView,
                                         self.eyebrowLabel,
                                         self.titleLabel,
                                         self.subtitleLabel,
                                         self.counterLabel];
    for (UIView *view in headlineViews) {
        view.alpha = 0.0;
        view.transform = CGAffineTransformMakeTranslation(0.0, 12.0);
    }

    NSArray<UIView *> *chromeViews = @[
                                       self.navCartButton ?: [UIView new]];
    for (UIView *view in chromeViews) {
        view.alpha = 0.0;
        view.transform = CGAffineTransformMakeTranslation(0.0, -10.0);
    }

    NSArray<UIView *> *contentViews = @[self.heroView,
                                        self.bottomSearchBarView,
                                        self.bottomSearchFadeView,
                                        self.collectionView,
                                        self.emptyView];
    for (UIView *view in contentViews) {
        view.alpha = 0.0;
        view.transform = CGAffineTransformMakeTranslation(0.0, 24.0);
    }

    self.searchPillView.alpha = 0.0;
    self.searchPillView.transform = CGAffineTransformMakeTranslation(0.0, 12.0);
    self.filterButton.alpha = 0.0;
    self.filterButton.transform = CGAffineTransformMakeTranslation(0.0, 12.0);
    self.heroIconView.alpha = 0.0;
    self.heroIconView.transform = CGAffineTransformMakeScale(0.90, 0.90);
    self.heroAnimationView.hidden = YES;
    self.heroAnimationView.alpha = 0.0;
    self.heroAnimationView.transform = CGAffineTransformMakeScale(0.88, 0.88);
}

- (void)pp_beginEntranceAnimationIfNeeded
{
    if (self.didAnimateEntrance) {
        return;
    }
    self.didAnimateEntrance = YES;

    NSArray<UIView *> *topChromeViews = @[self.sectionTitleContainer ?: [UIView new],
                                          self.navCartButton ?: [UIView new]];
    [topChromeViews enumerateObjectsUsingBlock:^(UIView * _Nonnull view, NSUInteger idx, BOOL * _Nonnull stop) {
        (void)stop;
        [UIView animateWithDuration:0.44
                              delay:0.02 * idx
                            options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
                         animations:^{
            view.alpha = 1.0;
            view.transform = CGAffineTransformIdentity;
        } completion:nil];
    }];

    [UIView animateWithDuration:0.58
                          delay:0.08
         usingSpringWithDamping:0.88
          initialSpringVelocity:0.14
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        self.heroView.alpha = 1.0;
        self.heroView.transform = CGAffineTransformIdentity;
    } completion:nil];

    NSArray<UIView *> *heroDetailViews = @[self.iconPlateView,
                                           self.heroIconView,
                                           self.eyebrowLabel,
                                           self.titleLabel,
                                           self.subtitleLabel,
                                           self.counterLabel];
    [heroDetailViews enumerateObjectsUsingBlock:^(UIView * _Nonnull view, NSUInteger idx, BOOL * _Nonnull stop) {
        (void)stop;
        [UIView animateWithDuration:0.46
                              delay:0.16 + (0.04 * idx)
             usingSpringWithDamping:0.90
              initialSpringVelocity:0.18
                            options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
                         animations:^{
            view.alpha = 1.0;
            view.transform = CGAffineTransformIdentity;
        } completion:nil];
    }];

    [UIView animateWithDuration:0.50
                          delay:0.28
         usingSpringWithDamping:0.90
          initialSpringVelocity:0.12
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        self.bottomSearchBarView.alpha = 1.0;
        self.bottomSearchBarView.transform = CGAffineTransformIdentity;
        self.bottomSearchFadeView.alpha = 1.0;
        self.bottomSearchFadeView.transform = CGAffineTransformIdentity;
        self.searchPillView.alpha = 1.0;
        self.searchPillView.transform = CGAffineTransformIdentity;
        self.filterButton.alpha = 1.0;
        self.filterButton.transform = CGAffineTransformIdentity;
    } completion:nil];

    [UIView animateWithDuration:0.56
                          delay:0.36
         usingSpringWithDamping:0.92
          initialSpringVelocity:0.10
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        self.collectionView.alpha = 1.0;
        self.collectionView.transform = CGAffineTransformIdentity;
        self.emptyView.alpha = self.emptyView.hidden ? 0.0 : 1.0;
        self.emptyView.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)pp_beginAmbientGlowAnimationIfNeeded
{
    if (self.didStartGlowAnimation || !self.didRevealLoadedDecor || UIAccessibilityIsReduceMotionEnabled()) {
        return;
    }
    self.didStartGlowAnimation = YES;

    [UIView animateWithDuration:6.0
                          delay:0.0
                        options:UIViewAnimationOptionAutoreverse | UIViewAnimationOptionRepeat | UIViewAnimationOptionCurveEaseInOut
                     animations:^{
        self.backgroundGlowTopView.transform = CGAffineTransformMakeTranslation(-16.0, 12.0);
        self.backgroundGlowMiddleView.transform = CGAffineTransformMakeTranslation(12.0, -10.0);
    } completion:nil];

    [UIView animateWithDuration:7.4
                          delay:0.0
                        options:UIViewAnimationOptionAutoreverse | UIViewAnimationOptionRepeat | UIViewAnimationOptionCurveEaseInOut
                     animations:^{
        self.backgroundGlowBottomView.transform = CGAffineTransformMakeTranslation(18.0, -14.0);
    } completion:nil];
}

- (void)pp_stopAmbientGlowAnimation
{
    self.didStartGlowAnimation = NO;
    for (UIView *view in @[self.backgroundGlowTopView,
                           self.backgroundGlowMiddleView,
                           self.backgroundGlowBottomView]) {
        [view.layer removeAllAnimations];
        if (!view.hidden) {
            view.transform = CGAffineTransformIdentity;
        }
    }
}

- (void)pp_noteInitialDataLoadProgress
{
    if (self.loadingMedicines || self.loadingVets) {
        return;
    }
    if (!self.didFinishInitialDataLoad) {
        self.didFinishInitialDataLoad = YES;
    }
    [self pp_revealLoadedDecorIfNeeded];
}

- (void)pp_revealLoadedDecorIfNeeded
{
    if (!self.didFinishInitialDataLoad || self.didRevealLoadedDecor || !self.isViewLoaded || !self.view.window) {
        return;
    }
    self.didRevealLoadedDecor = YES;

    NSArray<UIView *> *glowViews = @[self.backgroundGlowTopView,
                                     self.backgroundGlowMiddleView,
                                     self.backgroundGlowBottomView];

    if (UIAccessibilityIsReduceMotionEnabled()) {
        for (UIView *view in glowViews) {
            view.hidden = NO;
            view.alpha = 1.0;
            view.transform = CGAffineTransformIdentity;
        }
        [self pp_configureHeroAnimationIfNeeded];
        return;
    }

    [glowViews enumerateObjectsUsingBlock:^(UIView * _Nonnull view, NSUInteger idx, BOOL * _Nonnull stop) {
        (void)stop;
        view.hidden = NO;
        view.alpha = 0.0;
        view.transform = CGAffineTransformConcat(CGAffineTransformMakeScale(0.90, 0.90),
                                                 CGAffineTransformMakeTranslation(idx == 1 ? -10.0 : 10.0, 14.0));
        [UIView animateWithDuration:0.72
                              delay:0.06 + (0.055 * idx)
             usingSpringWithDamping:0.92
              initialSpringVelocity:0.08
                            options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                         animations:^{
            view.alpha = 1.0;
            view.transform = CGAffineTransformIdentity;
        } completion:nil];
    }];

    [self pp_configureHeroAnimationIfNeeded];
    [self pp_beginAmbientGlowAnimationIfNeeded];
}

- (void)pp_configureHeroAnimationIfNeeded
{
    NSString *animationName = PPPetCareHeroAnimationName(self.selectedSection);
    if (animationName.length == 0 || !self.heroAnimationView) {
        return;
    }

    if ([self.currentHeroAnimationName isEqualToString:animationName]) {
        BOOL needsReveal = self.heroAnimationView.hidden
            || self.heroAnimationView.alpha < 0.99
            || !CGAffineTransformEqualToTransform(self.heroAnimationView.transform, CGAffineTransformIdentity);
        if (needsReveal && self.heroAnimationView.sceneModel) {
            [self pp_revealResolvedHeroAnimation];
            return;
        }
        if (!self.heroAnimationView.hidden && !self.heroAnimationView.isAnimationPlaying) {
            [self.heroAnimationView play];
        }
        return;
    }

    self.currentHeroAnimationName = animationName;
    self.heroAnimationLoadToken += 1;
    NSInteger token = self.heroAnimationLoadToken;

    [self.heroAnimationView stop];
    self.heroAnimationView.hidden = YES;
    self.heroAnimationView.alpha = 0.0;
    self.heroIconView.hidden = NO;

    LOTComposition *premiumComposition = PPPetCarePremiumHeroComposition(self.selectedSection);
    if (premiumComposition) {
        self.heroAnimationView.animationSpeed = 0.84;
        [self.heroAnimationView setSceneModel:premiumComposition];
        [self pp_revealResolvedHeroAnimation];
        return;
    }

    __weak typeof(self) weakSelf = self;
    [AppClasses setAnimationNamed:animationName
                            ToView:self.heroAnimationView
                         withSpeed:0.84
                        completion:^(BOOL success) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self || self.heroAnimationLoadToken != token) {
                return;
            }

            if (!success) {
                self.heroAnimationView.hidden = YES;
                self.heroIconView.hidden = NO;
                return;
            }

            [self pp_revealResolvedHeroAnimation];
        });
    }];
}

- (void)pp_revealResolvedHeroAnimation
{
    if (!self.didFinishInitialDataLoad) {
        self.heroAnimationView.hidden = YES;
        self.heroAnimationView.alpha = 0.0;
        self.heroIconView.hidden = NO;
        return;
    }

    self.heroAnimationView.loopAnimation = YES;
    self.heroAnimationView.hidden = NO;
    self.heroIconView.hidden = YES;
    [self.heroAnimationView setNeedsLayout];
    [self.heroAnimationView layoutIfNeeded];
    [self.heroAnimationView play];

    if (UIAccessibilityIsReduceMotionEnabled()) {
        self.heroAnimationView.alpha = 1.0;
        self.heroAnimationView.transform = CGAffineTransformIdentity;
        return;
    }

    [UIView animateWithDuration:0.46
                          delay:self.didRevealLoadedDecor ? 0.20 : 0.34
         usingSpringWithDamping:0.91
          initialSpringVelocity:0.12
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.heroAnimationView.alpha = 1.0;
        self.heroAnimationView.transform = CGAffineTransformIdentity;
    } completion:nil];
}

#pragma mark - Navigation And Bottom Search

- (void)pp_applyKeyboardManagerOverridesIfNeeded
{
    IQKeyboardManager *manager = [IQKeyboardManager sharedManager];
    if (!self.isOverridingIQKeyboardManager) {
        self.previousIQKeyboardManagerEnabled = manager.enable;
        self.previousIQKeyboardToolbarEnabled = manager.enableAutoToolbar;
        self.isOverridingIQKeyboardManager = YES;
    }

    manager.enable = NO;
    manager.enableAutoToolbar = NO;
    self.searchField.inputAccessoryView = nil;
    [self.searchField reloadInputViews];
}

- (void)pp_restoreKeyboardManagerOverridesIfNeeded
{
    if (!self.isOverridingIQKeyboardManager) {
        return;
    }

    IQKeyboardManager *manager = [IQKeyboardManager sharedManager];
    manager.enable = self.previousIQKeyboardManagerEnabled;
    manager.enableAutoToolbar = self.previousIQKeyboardToolbarEnabled;
    self.isOverridingIQKeyboardManager = NO;
}

- (void)pp_installNavigationTitleControl
{
    if (!self.sectionControl) {
        return;
    }

    CGFloat segmentWidth = MAX(PPPetCareNavigationSegmentWidth(),
                               120.0 * MAX((CGFloat)self.sectionControl.numberOfSegments, 1.0));
    CGFloat segmentHeight = 34.0;
    if (!self.sectionTitleContainer) {
        self.sectionTitleContainer = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, segmentWidth, segmentHeight)];
        [self.sectionTitleContainer addSubview:self.sectionControl];
        [NSLayoutConstraint activateConstraints:@[
            [self.sectionControl.topAnchor constraintEqualToAnchor:self.sectionTitleContainer.topAnchor],
            [self.sectionControl.leadingAnchor constraintEqualToAnchor:self.sectionTitleContainer.leadingAnchor constant:-2],
            [self.sectionControl.trailingAnchor constraintEqualToAnchor:self.sectionTitleContainer.trailingAnchor constant:2],
            [self.sectionControl.bottomAnchor constraintEqualToAnchor:self.sectionTitleContainer.bottomAnchor]
        ]];
    }
    self.sectionTitleContainer.frame = CGRectMake(0.0, 0.0, segmentWidth, segmentHeight);
    self.sectionTitleContainer.bounds = CGRectMake(0.0, 0.0, segmentWidth, segmentHeight);

    self.navigationItem.title = nil;
    self.navigationItem.hidesBackButton = NO;
    if (self.navigationItem.titleView != self.sectionTitleContainer) {
        self.navigationItem.titleView = self.sectionTitleContainer;
    }
    [self pp_styleNavigationSectionControl];
}

- (void)pp_styleNavigationSectionControl
{
    if (!self.sectionControl) {
        return;
    }

    UIFont *normalFont = [GM MidFontWithSize:12.0] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightMedium];
    UIFont *selectedFont = [GM boldFontWithSize:12.0] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightSemibold];
    UIColor *normalColor = PPPetCareSecondaryTextColor();
    UIColor *selectedColor = PPPetCareTextColor();

    [self.sectionControl setTitleTextAttributes:@{
        NSFontAttributeName: normalFont,
        NSForegroundColorAttributeName: normalColor
    } forState:UIControlStateNormal];
    [self.sectionControl setTitleTextAttributes:@{
        NSFontAttributeName: selectedFont,
        NSForegroundColorAttributeName: selectedColor
    } forState:UIControlStateSelected];

    self.sectionControl.backgroundColor = PPPetCareSurfaceColor();
    self.sectionControl.selectedSegmentTintColor = [PPPetCareAccentColor() colorWithAlphaComponent:0.18];
    self.sectionControl.tintColor = PPPetCareAccentColor();
    self.sectionControl.apportionsSegmentWidthsByContent = NO;
    for (NSInteger segmentIndex = 0; segmentIndex < self.sectionControl.numberOfSegments; segmentIndex++) {
        [self.sectionControl setWidth:140.0 forSegmentAtIndex:segmentIndex];
    }
}

- (void)pp_installCartNavigationButton
{
    if (self.navCartButton && self.navigationItem.rightBarButtonItem.customView == self.navCartButton) {
        return;
    }

    UIButton *cartNavBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [cartNavBtn setImage:[UIImage systemImageNamed:@"cart.fill"] forState:UIControlStateNormal];
    [cartNavBtn addTarget:self action:@selector(onCartTapped) forControlEvents:UIControlEventTouchUpInside];
    cartNavBtn.accessibilityLabel = PPPetCareLocalized(@"Cart", @"Cart");

    if (!PPIOS26()) {
        cartNavBtn.backgroundColor = AppForgroundColr;
        cartNavBtn.layer.cornerRadius = 20.0;
        cartNavBtn.clipsToBounds = NO;
        [cartNavBtn.widthAnchor constraintEqualToConstant:40.0].active = YES;
        [cartNavBtn.heightAnchor constraintEqualToConstant:40.0].active = YES;
    }

    self.navCartButton = cartNavBtn;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:cartNavBtn];
    [self pp_updateCartBadge];
}

- (NSInteger)pp_currentCartItemCount
{
    return [CartManager.sharedManager totalItemsCount];
}

- (void)pp_updateCartBadge
{
    if (!self.navCartButton) {
        return;
    }

    UIButton *badgeHost = self.navCartButton;
    [badgeHost removeBadge];

    NSInteger count = [self pp_currentCartItemCount];
    if (count <= 0) {
        return;
    }

    NSString *badgeText = (count > 99) ? @"99+" : [NSString stringWithFormat:@"%ld", (long)count];
    UIColor *badgeColor = AppPrimaryClr ?: UIColor.systemPinkColor;

    void (^applyBadge)(void) = ^{
        UIButton *host = self.navCartButton;
        if (!host) return;

        [host layoutIfNeeded];
        if (CGRectIsEmpty(host.bounds)) return;

        [host removeBadge];
        [host addBadgeWithContent:badgeText
                       badgeColor:badgeColor
                           offset:CGPointMake(-10.0, 10.0)
                      badgeRadius:9.5];
    };

    applyBadge();
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.navigationController.navigationBar setNeedsLayout];
        [self.navigationController.navigationBar layoutIfNeeded];
        applyBadge();
    });
}

- (void)pp_handleCartUpdated:(NSNotification *)notification
{
    (void)notification;
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self pp_handleCartUpdated:nil];
        });
        return;
    }
    [self pp_updateCartBadge];
    if (self.selectedSection == PPPetCareInitialSectionMedicines) {
        [self pp_reloadVisibleMedicineCells];
    }
}

- (void)onCartTapped
{
    if (!UserManager.sharedManager.isUserLoggedIn) {
        [UserManager showPromptOnTopController];
        return;
    }

    CartViewController *vc = [[CartViewController alloc] init];
    PPNavigationController *nav = [[PPNavigationController alloc] initWithRootViewController:vc];
    nav.modalPresentationStyle = UIModalPresentationFullScreen;
    [PPHomeHelper presentViewControllerSafely:nav
                                         from:self
                                     animated:YES
                                   completion:nil];
}

- (void)pp_updateBottomSearchPositionAnimated:(BOOL)animated
                                 notification:(NSNotification *)notification
{
    if (!self.bottomSearchBarBottomConstraint) {
        return;
    }

    CGFloat safeBottom = self.view.safeAreaInsets.bottom;
    CGFloat restingInset = PPIOS26() ? 12.0 : MAX(safeBottom - 8.0, 12.0);
    CGFloat keyboardInset = self.keyboardOverlap + 12.0;
    CGFloat bottomInset = self.keyboardOverlap > 0.0 ? keyboardInset : restingInset;
    self.bottomSearchBarBottomConstraint.constant = -bottomInset;
    [self pp_updateCollectionBottomInsets];

    void (^changes)(void) = ^{
        self.bottomSearchBarView.transform = CGAffineTransformIdentity;
        [self.view layoutIfNeeded];
    };

    if (!animated) {
        changes();
        return;
    }

    NSTimeInterval duration = [notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    if (duration <= 0.0) {
        duration = 0.28;
    }
    UIViewAnimationCurve curve = [notification.userInfo[UIKeyboardAnimationCurveUserInfoKey] integerValue];
    UIViewAnimationOptions options = (curve << 16) | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction;

    [UIView animateWithDuration:duration
                          delay:0.0
                        options:options
                     animations:changes
                     completion:nil];
}

- (void)pp_updateCollectionBottomInsets
{
    if (!self.collectionView) {
        return;
    }

    CGFloat bottomInset = self.keyboardOverlap > 0.0 ? self.keyboardOverlap + 12.0 : self.view.safeAreaInsets.bottom;
    CGFloat bottomChrome = 92.0 + bottomInset;
    UIEdgeInsets contentInset = self.collectionView.contentInset;
    contentInset.bottom = bottomChrome;
    self.collectionView.contentInset = contentInset;

    UIEdgeInsets indicatorInset = self.collectionView.scrollIndicatorInsets;
    indicatorInset.bottom = bottomChrome;
    self.collectionView.scrollIndicatorInsets = indicatorInset;
}

- (void)pp_applyFilterButtonAppearance
{
    if (!self.filterButton) {
        return;
    }

    UIImage *filterIcon = [[UIImage systemImageNamed:@"slider.horizontal.3"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    if (PPIOS26()) {
        UIButtonConfiguration *configuration = [UIButtonConfiguration glassButtonConfiguration];
        configuration.image = filterIcon;
        configuration.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        configuration.baseForegroundColor = PPPetCareTextColor();
        configuration.contentInsets = NSDirectionalEdgeInsetsMake(0.0, 0.0, 0.0, 0.0);
        self.filterButton.configuration = configuration;
        self.filterButton.backgroundColor = UIColor.clearColor;
        self.filterButton.tintColor = PPPetCareTextColor();
        self.filterButton.layer.borderWidth = 0.0;
        self.filterButton.clipsToBounds = NO;
        return;
    }

    self.filterButton.configuration = nil;
    [self.filterButton setImage:filterIcon forState:UIControlStateNormal];
    self.filterButton.backgroundColor = PPPetCareSearchSurfaceColor();
    self.filterButton.tintColor = PPPetCareTextColor();
    self.filterButton.layer.borderWidth = 1.0;
    [self.filterButton pp_setBorderColor:PPPetCareSearchBorderColor()];
}

- (void)pp_keyboardWillChangeFrame:(NSNotification *)notification
{
    self.navigationItem.hidesBackButton = NO;
    CGRect keyboardEndFrame = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect keyboardFrameInView = [self.view convertRect:keyboardEndFrame fromView:nil];
    CGFloat overlap = CGRectGetMaxY(self.view.bounds) - CGRectGetMinY(keyboardFrameInView);
    self.keyboardOverlap = MAX(0.0, overlap);
    [self pp_updateBottomSearchPositionAnimated:YES notification:notification];
}

- (void)pp_keyboardWillHide:(NSNotification *)notification
{
    self.navigationItem.hidesBackButton = NO;
    self.keyboardOverlap = 0.0;
    [self pp_updateBottomSearchPositionAnimated:YES notification:notification];
}

#pragma mark - Data

- (void)pp_loadFilters
{
    NSArray *kinds = [MKM.MainKindsArray isKindOfClass:NSArray.class] ? MKM.MainKindsArray : @[];
    self.mainKinds = kinds;
    [self pp_updateFilterMenu];
}

- (void)pp_updateFilterMenu
{
    if (@available(iOS 14.0, *)) {
        NSMutableArray<UIAction *> *kindActions = [NSMutableArray array];
        __weak typeof(self) weakSelf = self;

        UIAction *allKindAction = [UIAction actionWithTitle:PPPetCareLocalized(@"pet_care_all_pets", @"All pets") image:nil identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
            weakSelf.selectedMainKind = nil;
            [weakSelf pp_applyFiltersAndReload];
            [weakSelf pp_updateFilterMenu];
        }];
        allKindAction.state = self.selectedMainKind == nil ? UIMenuElementStateOn : UIMenuElementStateOff;
        [kindActions addObject:allKindAction];

        for (MainKindsModel *kind in self.mainKinds) {
            NSString *title = kind.KindName.length > 0 ? kind.KindName : kind.KindNameEn ?: kind.KindNameAr ?: @"";
            UIAction *action = [UIAction actionWithTitle:title image:nil identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
                weakSelf.selectedMainKind = kind;
                [weakSelf pp_applyFiltersAndReload];
                [weakSelf pp_updateFilterMenu];
            }];
            action.state = (self.selectedMainKind && self.selectedMainKind.ID == kind.ID) ? UIMenuElementStateOn : UIMenuElementStateOff;
            [kindActions addObject:action];
        }

        UIMenu *kindMenu = [UIMenu menuWithTitle:PPPetCareLocalized(@"pet_care_kind_filter", @"Pet Kind") image:[UIImage systemImageNamed:@"pawprint.fill"] identifier:nil options:0 children:kindActions];

        NSMutableArray<UIAction *> *modeActions = [NSMutableArray array];
        NSArray<NSDictionary *> *items = self.selectedSection == PPPetCareInitialSectionMedicines
            ? @[
                @{@"title": PPPetCareLocalized(@"pet_care_filter_all", @"All"), @"tag": @(PPPetCareMedicineFilterAll)},
                @{@"title": PPPetCareLocalized(@"pet_care_filter_available", @"Available"), @"tag": @(PPPetCareMedicineFilterAvailable)},
                @{@"title": PPPetCareLocalized(@"pet_care_filter_in_stock", @"In stock"), @"tag": @(PPPetCareMedicineFilterInStock)},
                @{@"title": PPPetCareLocalized(@"pet_care_filter_new", @"New"), @"tag": @(PPPetCareMedicineFilterNew)}
            ]
            : @[
                @{@"title": PPPetCareLocalized(@"pet_care_filter_all", @"All"), @"tag": @(PPPetCareVetFilterAll)},
                @{@"title": PPPetCareLocalized(@"pet_care_filter_with_phone", @"Contact ready"), @"tag": @(PPPetCareVetFilterWithPhone)},
                @{@"title": PPPetCareLocalized(@"pet_care_filter_clinics", @"Clinics"), @"tag": @(PPPetCareVetFilterCompany)},
                @{@"title": PPPetCareLocalized(@"pet_care_filter_doctors", @"Doctors"), @"tag": @(PPPetCareVetFilterPersonal)}
            ];

        for (NSDictionary *item in items) {
            NSInteger tag = [item[@"tag"] integerValue];
            BOOL isSelected = self.selectedSection == PPPetCareInitialSectionMedicines
                ? tag == self.medicineFilter
                : tag == self.vetFilter;

            UIAction *action = [UIAction actionWithTitle:item[@"title"] image:nil identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
                if (weakSelf.selectedSection == PPPetCareInitialSectionMedicines) {
                    weakSelf.medicineFilter = (PPPetCareMedicineFilter)tag;
                } else {
                    weakSelf.vetFilter = (PPPetCareVetFilter)tag;
                }
                [weakSelf pp_applyFiltersAndReload];
                [weakSelf pp_updateFilterMenu];
            }];
            action.state = isSelected ? UIMenuElementStateOn : UIMenuElementStateOff;
            [modeActions addObject:action];
        }

        UIMenu *modeMenu = [UIMenu menuWithTitle:PPPetCareLocalized(@"pet_care_filter_by", @"Filter By") image:[UIImage systemImageNamed:@"line.3.horizontal.decrease"] identifier:nil options:0 children:modeActions];

        UIMenu *mainMenu = [UIMenu menuWithTitle:@"" image:nil identifier:nil options:UIMenuOptionsDisplayInline children:@[kindMenu, modeMenu]];
        self.filterButton.menu = mainMenu;
    }
}

- (void)pp_loadData
{
    self.loadingMedicines = YES;
    self.loadingVets = YES;
    [self pp_updateEmptyState];

    __weak typeof(self) weakSelf = self;
    [[VetManager sharedManager] fetchAllPetMedicinesWithCompletion:^(NSArray<VetMedicineModel *> *medicinesArray, NSError * _Nullable error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        self.loadingMedicines = NO;
        NSArray<VetMedicineModel *> *medicines = medicinesArray ?: @[];
        self.allMedicines = [medicines sortedArrayUsingComparator:^NSComparisonResult(VetMedicineModel *a, VetMedicineModel *b) {
            return [PPPetCareSafeString(a.title) localizedCaseInsensitiveCompare:PPPetCareSafeString(b.title)];
        }];
        [self pp_applyFiltersAndReload];
        [self pp_noteInitialDataLoadProgress];
    }];

    [[VetManager sharedManager] fetchAllVetsWithCompletion:^(NSArray<VetModel *> *vetsArray, NSError * _Nullable error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        self.loadingVets = NO;
        NSArray *vets = vetsArray ?: @[];
        self.allVets = [vets sortedArrayUsingComparator:^NSComparisonResult(VetModel *a, VetModel *b) {
            return [PPPetCareSafeString(a.title) localizedCaseInsensitiveCompare:PPPetCareSafeString(b.title)];
        }];
        [self pp_applyFiltersAndReload];
        [self pp_noteInitialDataLoadProgress];
    }];
}

- (void)pp_applyFiltersAndReload
{
    NSString *query = PPPetCareNormalizedText(self.searchField.text);
    NSInteger kindID = self.selectedMainKind ? self.selectedMainKind.ID : 0;

    BOOL hasActiveFilter = (kindID > 0);
    if (self.selectedSection == PPPetCareInitialSectionMedicines) {
        hasActiveFilter = hasActiveFilter || (self.medicineFilter != PPPetCareMedicineFilterAll);
    } else {
        hasActiveFilter = hasActiveFilter || (self.vetFilter != PPPetCareVetFilterAll);
    }
    self.filterBadgeView.hidden = !hasActiveFilter;

    NSMutableArray<VetMedicineModel *> *medicines = [NSMutableArray array];
    for (VetMedicineModel *item in self.allMedicines) {
        if (kindID > 0 && ![self pp_animalTypes:item.animalTypes matchMainKind:self.selectedMainKind]) {
            continue;
        }
        if (![self pp_medicine:item matchesFilter:self.medicineFilter]) {
            continue;
        }
        if (query.length > 0) {
            NSString *haystack = PPPetCareNormalizedText([@[PPPetCareSafeString(item.title),
                                                           PPPetCareSafeString(item.title_lowercase)]
                                                         componentsJoinedByString:@" "]);
            if (![haystack containsString:query]) {
                continue;
            }
        }
        [medicines addObject:item];
    }
    self.filteredMedicines = medicines.copy;

    NSMutableArray<VetModel *> *vets = [NSMutableArray array];
    for (VetModel *vet in self.allVets) {
        if (kindID > 0 && ![self pp_vet:vet matchesMainKind:self.selectedMainKind]) {
            continue;
        }
        if (![self pp_vet:vet matchesFilter:self.vetFilter]) {
            continue;
        }
        if (query.length > 0) {
            NSString *haystack = PPPetCareNormalizedText([@[PPPetCareSafeString(vet.title),
                                                           PPPetCareSafeString(vet.name_lowercase)]
                                                         componentsJoinedByString:@" "]);
            if (![haystack containsString:query]) {
                continue;
            }
        }
        [vets addObject:vet];
    }
    self.filteredVets = vets.copy;

    [self.collectionView reloadData];
    [self pp_updateCounter];
    [self pp_updateEmptyState];
}

- (BOOL)pp_medicine:(VetMedicineModel *)medicine matchesFilter:(PPPetCareMedicineFilter)filter
{
    if (medicine.isPublished == NO || medicine.isDisabled) {
        return NO;
    }
    switch (filter) {
        case PPPetCareMedicineFilterAvailable:
            return medicine.isAvailable && medicine.stockQuantity > 0;
        case PPPetCareMedicineFilterInStock:
            return medicine.stockQuantity > 0;
        case PPPetCareMedicineFilterNew:
            if (!medicine.createdAt) {
                return YES;
            }
            return [medicine.createdAt timeIntervalSinceNow] >= -(14.0 * 24.0 * 60.0 * 60.0);
        case PPPetCareMedicineFilterAll:
        default:
            return YES;
    }
}

- (BOOL)pp_vet:(VetModel *)vet matchesFilter:(PPPetCareVetFilter)filter
{
    if (vet.isDisabled) {
        return NO;
    }
    if (![self pp_vetIsApprovedForListing:vet]) {
        return NO;
    }
    switch (filter) {
        case PPPetCareVetFilterWithPhone:
            return vet.readyToContact || vet.phone.length > 0 || vet.whatsapp.length > 0;
        case PPPetCareVetFilterCompany:
            return vet.type == VetTypeCompany;
        case PPPetCareVetFilterPersonal:
            return vet.type == VetTypePersonal;
        case PPPetCareVetFilterAll:
        default:
            return YES;
    }
}

- (BOOL)pp_vetIsApprovedForListing:(VetModel *)vet
{
    NSString *verificationStatus = PPPetCareSafeString(vet.verificationStatus).lowercaseString;
    if (verificationStatus.length == 0) {
        return YES;
    }

    static NSSet<NSString *> *approvedStatuses = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        approvedStatuses = [NSSet setWithArray:@[@"approved", @"active", @"verified"]];
    });

    return [approvedStatuses containsObject:verificationStatus];
}

- (BOOL)pp_animalTypes:(NSArray<NSString *> *)animalTypes matchMainKind:(MainKindsModel *)mainKind
{
    if (!mainKind) {
        return YES;
    }
    if (animalTypes.count == 0) {
        return YES;
    }

    NSMutableArray<NSString *> *candidates = [NSMutableArray array];
    if (mainKind.ID > 0) {
        [candidates addObject:[NSString stringWithFormat:@"%ld", (long)mainKind.ID]];
    }
    for (NSString *value in @[PPPetCareSafeString(mainKind.KindName), PPPetCareSafeString(mainKind.KindNameEn), PPPetCareSafeString(mainKind.KindNameAr)]) {
        NSString *normalized = PPPetCareNormalizedText(value);
        if (normalized.length > 0) {
            [candidates addObject:normalized];
        }
    }

    for (NSString *animalType in animalTypes) {
        NSString *normalizedAnimalType = PPPetCareNormalizedText(animalType);
        for (NSString *candidate in candidates) {
            if ([normalizedAnimalType isEqualToString:candidate]) {
                return YES;
            }
        }
    }
    return NO;
}

- (BOOL)pp_vet:(VetModel *)vet matchesMainKind:(MainKindsModel *)mainKind
{
    if (!mainKind) {
        return YES;
    }
    if (vet.animalTypes.count > 0) {
        return [self pp_animalTypes:vet.animalTypes matchMainKind:mainKind];
    }
    return vet.petMainKindID == mainKind.ID;
}

#pragma mark - Localization and Theme

- (void)pp_updateLocalizedText
{
    [self pp_installNavigationTitleControl];
    [self.sectionControl setTitle:PPPetCareLocalized(@"pet_care_medicines", @"Medicines") forSegmentAtIndex:0];
    [self.sectionControl setTitle:PPPetCareLocalized(@"pet_care_veterinarians", @"Veterinarians") forSegmentAtIndex:1];
    self.searchField.placeholder = self.selectedSection == PPPetCareInitialSectionMedicines
        ? PPPetCareLocalized(@"pet_care_search_medicines", @"Search medicines")
        : PPPetCareLocalized(@"pet_care_search_vets", @"Search veterinarians");
    self.eyebrowLabel.text = PPPetCareLocalized(@"pet_care_eyebrow", @"Premium care");
    self.titleLabel.text = self.selectedSection == PPPetCareInitialSectionMedicines
        ? PPPetCareLocalized(@"pet_care_medicine_title", @"Pet medicines")
        : PPPetCareLocalized(@"pet_care_vets_title", @"Veterinarians");
    self.subtitleLabel.text = self.selectedSection == PPPetCareInitialSectionMedicines
        ? PPPetCareLocalized(@"pet_care_medicine_subtitle", @"Curated treatment, wellness, and care supplies from the shared store catalog.")
        : PPPetCareLocalized(@"pet_care_vets_subtitle", @"Find veterinarians matched to pet kind, contact readiness, and clinic type.");
    self.sectionControl.selectedSegmentIndex = self.selectedSection == PPPetCareInitialSectionVeterinarians ? 1 : 0;
    self.view.semanticContentAttribute = Language.isRTL ? UISemanticContentAttributeForceRightToLeft : UISemanticContentAttributeForceLeftToRight;
    self.sectionTitleContainer.semanticContentAttribute = self.view.semanticContentAttribute;
    self.bottomSearchBarView.semanticContentAttribute = self.view.semanticContentAttribute;
    self.searchPillView.semanticContentAttribute = self.view.semanticContentAttribute;
    self.searchField.semanticContentAttribute = self.view.semanticContentAttribute;
    self.searchIconView.semanticContentAttribute = self.view.semanticContentAttribute;
    self.searchField.textAlignment = [Language alignmentForCurrentLanguage];
    self.eyebrowLabel.textAlignment = [Language alignmentForCurrentLanguage];
    self.titleLabel.textAlignment = [Language alignmentForCurrentLanguage];
    self.subtitleLabel.textAlignment = [Language alignmentForCurrentLanguage];

    self.heroIconView.image = [[UIImage systemImageNamed:self.selectedSection == PPPetCareInitialSectionMedicines ? @"pills.fill" : @"cross.case.fill"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    [self pp_configureHeroAnimationIfNeeded];

    [self pp_updateFilterMenu];
    [self pp_updateCounter];
    [self pp_updateEmptyState];
}

- (void)pp_applyTheme
{
    BOOL dark = NO;
    if (@available(iOS 13.0, *)) {
        dark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    }

    UIColor *accent = PPPetCareAccentColor();
    self.view.backgroundColor = AppBackgroundClr;
    self.heroView.backgroundColor = PPPetCareSurfaceColor();
    [self.heroView pp_setBorderColor:PPPetCareBorderColor()];
    self.heroView.layer.shadowOpacity = dark ? 0.0 : 0.08;

    UIColor *glowHighlight = [UIColor colorWithWhite:1.0 alpha:dark ? 0.03 : 0.10];
    self.heroGradientLayer.colors = @[
        (id)[accent colorWithAlphaComponent:dark ? 0.20 : 0.13].CGColor,
        (id)[UIColor clearColor].CGColor
    ];
    self.backgroundGlowTopView.backgroundColor = [accent colorWithAlphaComponent:dark ? 0.14 : 0.17];
    self.backgroundGlowTopView.layer.shadowColor = [accent colorWithAlphaComponent:dark ? 0.24 : 0.22].CGColor;
    self.backgroundGlowMiddleView.backgroundColor = glowHighlight;
    self.backgroundGlowMiddleView.layer.shadowColor = glowHighlight.CGColor;
    self.backgroundGlowBottomView.backgroundColor = [accent colorWithAlphaComponent:dark ? 0.10 : 0.12];
    self.backgroundGlowBottomView.layer.shadowColor = [accent colorWithAlphaComponent:dark ? 0.16 : 0.18].CGColor;
    self.largeOrbView.backgroundColor = [accent colorWithAlphaComponent:dark ? 0.12 : 0.08];
    self.smallOrbView.backgroundColor = [accent colorWithAlphaComponent:dark ? 0.0 : 0.0];

    self.iconPlateView.backgroundColor = [accent colorWithAlphaComponent:dark ? 0.18 : 0.11];
    [self.iconPlateView pp_setBorderColor:[accent colorWithAlphaComponent:dark ? 0.24 : 0.16]];
    self.heroIconView.tintColor = accent;

    self.eyebrowLabel.textColor = [accent colorWithAlphaComponent:dark ? 0.92 : 0.82];
    self.titleLabel.textColor = PPPetCareTextColor();
    self.subtitleLabel.textColor = PPPetCareSecondaryTextColor();
    self.counterLabel.textColor = PPPetCareTextColor();
    self.counterLabel.backgroundColor = [accent colorWithAlphaComponent:dark ? 0.15 : 0.09];
    [self.counterLabel pp_setBorderColor:PPPetCareBorderColor()];

    self.bottomSearchBarView.layer.shadowOpacity = dark ? 0.22 : 0.14;
    self.searchPillView.backgroundColor = PPPetCareSearchSurfaceColor();
    [self.searchPillView pp_setBorderColor:PPPetCareSearchBorderColor()];
    self.bottomSearchFadeLayer.colors = @[
        (id)[UIColor clearColor].CGColor,
        (id)[[AppBackgroundClr colorWithAlphaComponent:dark ? 0.05 : 0.035] CGColor],
        (id)[[PPPetCareSurfaceColor() colorWithAlphaComponent:dark ? 0.96 : 0.92] CGColor]
    ];
    self.bottomSearchFadeLayer.locations = @[@0.0, @0.38, @1.0];
    self.searchField.textColor = PPPetCareTextColor();
    self.searchField.backgroundColor = UIColor.clearColor;
    self.searchField.tintColor = PPPetCareAccentColor();
    self.searchIconView.tintColor = PPPetCareTextColor();

    [self pp_applyFilterButtonAppearance];

    UIColor *badgeBorderColor = PPIOS26() ? [PPPetCareSurfaceColor() colorWithAlphaComponent:0.72] : self.filterButton.backgroundColor;
    self.filterBadgeView.layer.borderColor = badgeBorderColor.CGColor;

    [self pp_styleNavigationSectionControl];
}

- (void)pp_updateCounter
{
    NSInteger count = self.selectedSection == PPPetCareInitialSectionMedicines
        ? self.filteredMedicines.count
        : self.filteredVets.count;
    NSString *format = self.selectedSection == PPPetCareInitialSectionMedicines
        ? PPPetCareLocalized(@"pet_care_medicine_count_format", @"%ld medicines")
        : PPPetCareLocalized(@"pet_care_vet_count_format", @"%ld vets");
    self.counterLabel.text = [NSString stringWithFormat:format, (long)count];
}

- (void)pp_updateEmptyState
{
    BOOL isLoading = self.selectedSection == PPPetCareInitialSectionMedicines ? self.loadingMedicines : self.loadingVets;
    NSInteger count = self.selectedSection == PPPetCareInitialSectionMedicines ? self.filteredMedicines.count : self.filteredVets.count;
    self.emptyView.hidden = isLoading || count > 0;
    if (isLoading) {
        return;
    }
    if (self.selectedSection == PPPetCareInitialSectionMedicines) {
        self.emptyTitleLabel.text = PPPetCareLocalized(@"pet_care_empty_medicines_title", @"No medicines found");
        self.emptySubtitleLabel.text = PPPetCareLocalized(@"pet_care_empty_medicines_subtitle", @"Try another pet kind, remove filters, or search with a shorter word.");
    } else {
        self.emptyTitleLabel.text = PPPetCareLocalized(@"pet_care_empty_vets_title", @"No veterinarians found");
        self.emptySubtitleLabel.text = PPPetCareLocalized(@"pet_care_empty_vets_subtitle", @"Try all pet kinds, contact-ready filters, or a different search term.");
    }
}

#pragma mark - Actions

- (void)pp_sectionChanged:(UISegmentedControl *)sender
{
    self.selectedSection = sender.selectedSegmentIndex == 1
        ? PPPetCareInitialSectionVeterinarians
        : PPPetCareInitialSectionMedicines;
    [self pp_updateLocalizedText];
    [self pp_applyFiltersAndReload];
}

- (void)pp_kindChipTapped:(UIButton *)sender
{
    if (sender.tag == 0) {
        self.selectedMainKind = nil;
    } else {
        NSInteger index = sender.tag - 1;
        self.selectedMainKind = (index >= 0 && index < self.mainKinds.count) ? self.mainKinds[index] : nil;
    }
    [self pp_applyFiltersAndReload];
    [self pp_updateFilterMenu];
}

- (void)pp_filterChipTapped:(UIButton *)sender
{
    if (self.selectedSection == PPPetCareInitialSectionMedicines) {
        self.medicineFilter = (PPPetCareMedicineFilter)sender.tag;
    } else {
        self.vetFilter = (PPPetCareVetFilter)sender.tag;
    }
    [self pp_applyFiltersAndReload];
    [self pp_updateFilterMenu];
}

- (void)pp_searchTextChanged:(UITextField *)textField
{
    [self pp_applyFiltersAndReload];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    return YES;
}

#pragma mark - Collection

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    if (self.selectedSection == PPPetCareInitialSectionMedicines) {
        return self.filteredMedicines.count;
    }
    return self.filteredVets.count;
}

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                          cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.selectedSection == PPPetCareInitialSectionMedicines) {
        id cell = [PPUniversalCell pp_dequeueFromCollectionView:collectionView indexPath:indexPath];
        cell.delegate = self;
        cell.indexPath = indexPath;
        cell.hideTopBadge = YES;
        cell.showsSubtitle = YES;
        cell.onTap = nil;
        if (indexPath.item < self.filteredMedicines.count) {
            VetMedicineModel *medicine = self.filteredMedicines[indexPath.item];
            NSString *mainKindName = self.selectedMainKind ? [self pp_mainKindNameForID:self.selectedMainKind.ID] : PPPetCareLocalized(@"pet_care_all_pets", @"All pets");
            PPUniversalCellViewModel *vm = [self pp_universalViewModelForMedicine:medicine
                                                                      mainKindName:mainKindName
                                                                        indexPath:indexPath];
            [cell applyViewModel:vm
                         context:PPCellForMarket
                       layoutMode:PPCellLayoutModeHorizontalRow
                     discountMode:PPDiscountStylePlain
                      imageLoader:^(UIImageView *imageView,
                                    NSString *url,
                                    UIImage *placeholder,
                                    UIView *card) {
                (void)card;
                imageView.contentMode = UIViewContentModeScaleAspectFill;
                imageView.clipsToBounds = YES;
                [[PPImageLoaderManager shared] setImageOnImageView:imageView
                                                               url:url
                                                       placeholder:placeholder
                                                  transitionStyle:PPImageTransitionStyleFade
                                                        complation:nil];
            }];
            cell.selected = [PPPetCareMedicineItemIdentifier(medicine) isEqualToString:self.selectedMedicineID];
        }
        return cell;
    }

    PPPetCareVetCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:PPPetCareVetCell.reuseIdentifier
                                                                       forIndexPath:indexPath];
    if (indexPath.item < self.filteredVets.count) {
        VetModel *vet = self.filteredVets[indexPath.item];
        [cell configureWithVet:vet mainKindName:[self pp_mainKindNameForID:vet.petMainKindID]];
        __weak typeof(self) weakSelf = self;
        cell.onDetailsTap = ^{
            __strong typeof(weakSelf) self = weakSelf;
            [self pp_openObject:vet];
        };
        cell.onCallTap = ^{
            __strong typeof(weakSelf) self = weakSelf;
            [self pp_callVet:vet];
        };
    }
    return cell;
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    CGFloat width = CGRectGetWidth(collectionView.bounds);
    UIEdgeInsets inset = ((UICollectionViewFlowLayout *)collectionViewLayout).sectionInset;
    CGFloat available = width - inset.left - inset.right;
    if (self.selectedSection == PPPetCareInitialSectionMedicines) {
        BOOL twoColumns = available >= 360.0;
        CGFloat itemWidth = twoColumns ? floor((available - 12.0) / 2.0) : available;
        return CGSizeMake(itemWidth, MAX(324.0, itemWidth * 1.42));
    }
    return CGSizeMake(available, 206.0);
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.selectedSection == PPPetCareInitialSectionMedicines) {
        if (indexPath.item < self.filteredMedicines.count) {
            [self pp_selectMedicine:self.filteredMedicines[indexPath.item]];
        }
        return;
    } else {
        if (indexPath.item < self.filteredVets.count) {
            [self pp_openObject:self.filteredVets[indexPath.item]];
        }
    }
}

- (void)collectionView:(UICollectionView *)collectionView didHighlightItemAtIndexPath:(NSIndexPath *)indexPath
{
    UICollectionViewCell *cell = [collectionView cellForItemAtIndexPath:indexPath];
    [UIView animateWithDuration:0.12 animations:^{
        cell.transform = CGAffineTransformMakeScale(0.985, 0.985);
        cell.alpha = 0.92;
    }];
}

- (void)collectionView:(UICollectionView *)collectionView didUnhighlightItemAtIndexPath:(NSIndexPath *)indexPath
{
    UICollectionViewCell *cell = [collectionView cellForItemAtIndexPath:indexPath];
    [UIView animateWithDuration:0.20
                          delay:0.0
         usingSpringWithDamping:0.78
          initialSpringVelocity:0.4
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        cell.transform = CGAffineTransformIdentity;
        cell.alpha = 1.0;
    } completion:nil];
}

#pragma mark - Universal Cell

- (void)PPUniversalCell_tapCard:(PPUniversalCellViewModel *)universalModel
{
    if ([universalModel.ModelObject isKindOfClass:VetMedicineModel.class]) {
        [self pp_selectMedicine:(VetMedicineModel *)universalModel.ModelObject];
    }
    [self pp_openObject:universalModel.ModelObject];
}

- (void)PPUniversalCell_changeQuantity:(PPUniversalCellViewModel *)vm
                              quantity:(NSInteger)quantity
{
    if (![vm.ModelObject isKindOfClass:VetMedicineModel.class]) {
        return;
    }

    VetMedicineModel *medicine = (VetMedicineModel *)vm.ModelObject;
    [self pp_selectMedicine:medicine];

    if (![PPNetworkRetryHelper isNetworkAvailable]) {
        [PPAlertHelper showWarningIn:self
                               title:kLang(@"offline_action_title")
                            subtitle:kLang(@"offline_action_message")
                          completion:nil];
        [self pp_reloadMedicineCellForViewModel:vm];
        return;
    }

    if (![self pp_ensureSignedInForAction]) {
        [self pp_reloadMedicineCellForViewModel:vm];
        return;
    }

    NSInteger maxStock = MAX(medicine.stockQuantity, 0);
    NSInteger safeQuantity = MAX(0, quantity);

    if (!medicine.isAvailable || maxStock <= 0) {
        if (safeQuantity > 0) {
            [PPHUD showError:kLang(@"Out of stock")];
            [PPFunc triggerWarningHaptic];
        }
        [self pp_reloadMedicineCellForViewModel:vm];
        return;
    }

    if (safeQuantity > maxStock) {
        safeQuantity = maxStock;
        [PPHUD showInfo:[NSString stringWithFormat:@"%@ %ld %@",
                         kLang(@"Only"),
                         (long)maxStock,
                         kLang(@"left in stock")]];
    }

    CartManager *cart = [CartManager sharedManager];
    NSString *itemID = PPPetCareMedicineItemIdentifier(medicine);
    CartItem *existing = itemID.length > 0 ? [cart getCartItemForItemID:itemID] : nil;

    if (safeQuantity == 0) {
        if (existing) {
            [cart removeItem:existing];
            [PPFunc triggerWarningHaptic];
        }
        [self pp_reloadMedicineCellForViewModel:vm];
        return;
    }

    CartItem *item = PPPetCareCartItemForMedicine(medicine, safeQuantity);
    if (!item) {
        [self pp_reloadMedicineCellForViewModel:vm];
        return;
    }

    if (existing) {
        __weak typeof(self) weakSelf = self;
        [cart updateQuantity:safeQuantity
                     forItem:item
                  completion:^(BOOL success) {
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(weakSelf) self = weakSelf;
                if (!success) {
                    [PPHUD showError:kLang(@"Out of stock")];
                    [PPFunc triggerWarningHaptic];
                } else if (safeQuantity == 1) {
                    [PPFunc triggerLightHaptic];
                } else {
                    [PPFunc triggerMediumHaptic];
                }
                [self pp_reloadMedicineCellForViewModel:vm];
                [self pp_updateCartBadge];
            });
        }];
        return;
    }

    __weak typeof(self) weakSelf = self;
    [cart addItem:item
presentingViewController:self
       completion:^(BOOL didAdd, BOOL didCancel) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) { return; }
        if (didCancel) {
            [self pp_reloadMedicineCellForViewModel:vm];
            return;
        }
        if (!didAdd) {
            [PPHUD showError:kLang(@"Out of stock")];
            [PPFunc triggerWarningHaptic];
            [self pp_reloadMedicineCellForViewModel:vm];
            return;
        }

        if (safeQuantity == 1) {
            [PPFunc triggerLightHaptic];
        } else {
            [PPFunc triggerMediumHaptic];
        }
        [self pp_updateCartBadge];
        [self pp_reloadMedicineCellForViewModel:vm];
    }];
}

- (PPUniversalCellViewModel *)pp_universalViewModelForMedicine:(VetMedicineModel *)medicine
                                                   mainKindName:(NSString *)mainKindName
                                                     indexPath:(NSIndexPath *)indexPath
{
    PPUniversalCellViewModel *vm = [[PPUniversalCellViewModel alloc] initWithModel:nil
                                                                           context:PPCellForMarket];
    NSString *currency = medicine.currency.length > 0 ? medicine.currency : @"QAR";
    NSNumber *price = @(MAX(medicine.price, 0.0));
    NSString *fallbackTitle = PPPetCareLocalized(@"pet_care_medicine_untitled", @"Medicine");
    NSString *fallbackSubtitle = PPPetCareLocalized(@"pet_care_medicine_default_subtitle", @"Care essentials prepared by approved veterinary partners.");
    NSString *stockText = medicine.stockQuantity > 0
        ? [NSString stringWithFormat:PPPetCareLocalized(@"pet_care_viewer_stock_units_format", @"%ld in stock"), (long)medicine.stockQuantity]
        : PPPetCareLocalized(@"pet_care_medicine_out_of_stock", @"Out of stock");

    vm.ModelObject = medicine;
    vm.ModelID = PPPetCareMedicineItemIdentifier(medicine);
    vm.modelType = NSStringFromClass([VetMedicineModel class]);
    vm.modelContext = PPCellForMarket;
    vm.indexPath = indexPath;
    vm.title = medicine.title.length > 0 ? medicine.title : fallbackTitle;
    vm.subtitle = medicine.medicineDescription.length > 0 ? medicine.medicineDescription : fallbackSubtitle;
    vm.price = price;
    vm.finalPrice = price;
    vm.priceText = [GM formatPrice:price currencyCode:currency] ?: [NSString stringWithFormat:@"%.2f %@", medicine.price, currency];
    vm.currencyCode = currency;
    vm.imageURL = medicine.imageUrl ?: @"";
    vm.blurHash = medicine.blurHash ?: @"";
    vm.placeholder = [UIImage imageNamed:@"petcare_placeholder"];
    vm.preferredAspectRatio = 0.78;
    vm.imageSize = CGSizeMake(1.0, 0.78);
    vm.itemQuantitiy = MAX(medicine.stockQuantity, 0);
    vm.availabilityText = medicine.isAvailable && medicine.stockQuantity > 0
        ? PPPetCareLocalized(@"pet_care_medicine_available", @"Available")
        : PPPetCareLocalized(@"pet_care_medicine_not_available", @"Not available");
    vm.stockStatusText = stockText;
    vm.badgeText = mainKindName.length > 0 ? mainKindName : PPPetCareLocalized(@"pet_care_all_pets", @"All pets");
    vm.location = @"";
    vm.isOwner = NO;
    vm.isNew = medicine.createdAt == nil || [medicine.createdAt timeIntervalSinceNow] >= -(14.0 * 24.0 * 60.0 * 60.0);
    vm.hasOffer = NO;

    return vm;
}

- (NSIndexPath *)pp_indexPathForMedicineID:(NSString *)medicineID
{
    if (medicineID.length == 0) {
        return nil;
    }

    NSUInteger index = [self.filteredMedicines indexOfObjectPassingTest:^BOOL(VetMedicineModel * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        (void)idx;
        return [PPPetCareMedicineItemIdentifier(obj) isEqualToString:medicineID];
    }];
    if (index == NSNotFound) {
        return nil;
    }
    return [NSIndexPath indexPathForItem:index inSection:0];
}

- (void)pp_selectMedicine:(VetMedicineModel *)medicine
{
    NSString *medicineID = PPPetCareMedicineItemIdentifier(medicine);
    NSString *previousID = self.selectedMedicineID ?: @"";
    if ((medicineID.length == 0 && previousID.length == 0) || [previousID isEqualToString:medicineID]) {
        return;
    }

    self.selectedMedicineID = medicineID ?: @"";
    if (!self.collectionView) {
        return;
    }

    NSMutableArray<NSIndexPath *> *indexPaths = [NSMutableArray array];
    NSIndexPath *previousIndexPath = [self pp_indexPathForMedicineID:previousID];
    NSIndexPath *currentIndexPath = [self pp_indexPathForMedicineID:self.selectedMedicineID];
    if (previousIndexPath) {
        [indexPaths addObject:previousIndexPath];
    }
    if (currentIndexPath && ![currentIndexPath isEqual:previousIndexPath]) {
        [indexPaths addObject:currentIndexPath];
    }

    if (indexPaths.count > 0) {
        [self.collectionView reloadItemsAtIndexPaths:indexPaths];
    } else {
        [self.collectionView reloadData];
    }
}

- (void)pp_reloadMedicineCellForViewModel:(PPUniversalCellViewModel *)vm
{
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self pp_reloadMedicineCellForViewModel:vm];
        });
        return;
    }

    if (!self.collectionView || self.selectedSection != PPPetCareInitialSectionMedicines) {
        return;
    }

    NSIndexPath *indexPath = vm.indexPath;
    if ((!indexPath || indexPath.item >= self.filteredMedicines.count) && vm.ModelID.length > 0) {
        indexPath = [self pp_indexPathForMedicineID:vm.ModelID];
    }

    if (indexPath && indexPath.item < self.filteredMedicines.count) {
        [self.collectionView reloadItemsAtIndexPaths:@[indexPath]];
        return;
    }

    [self pp_reloadVisibleMedicineCells];
}

- (void)pp_reloadVisibleMedicineCells
{
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self pp_reloadVisibleMedicineCells];
        });
        return;
    }

    if (!self.collectionView || self.selectedSection != PPPetCareInitialSectionMedicines) {
        return;
    }

    NSArray<NSIndexPath *> *visible = self.collectionView.indexPathsForVisibleItems;
    if (visible.count == 0) {
        return;
    }
    [self.collectionView reloadItemsAtIndexPaths:visible];
}

- (BOOL)pp_ensureSignedInForAction
{
    if (UserManager.sharedManager.isUserLoggedIn) {
        return YES;
    }
    [PPFunc triggerWarningHaptic];
    [UserManager showPromptOnTopController];
    return NO;
}

#pragma mark - Routing

- (void)pp_openObject:(id)object
{
    if (!object) {
        return;
    }
    if ([object isKindOfClass:VetMedicineModel.class]) {
        [self pp_presentMedicineDetails:(VetMedicineModel *)object];
        return;
    }
    if ([object isKindOfClass:VetModel.class]) {
        [self pp_presentVetDetails:(VetModel *)object];
        return;
    }
    [PPOverlayCoordinator pp_openDetailForObject:object
                                         fromVC:self
                                     routingNav:(PPNavigationController *)self.navigationController];
}

- (void)pp_presentMedicineDetails:(VetMedicineModel *)medicine
{
    NSString *mainKindName = self.selectedMainKind
        ? [self pp_mainKindNameForID:self.selectedMainKind.ID]
        : PPPetCareLocalized(@"pet_care_all_pets", @"All pets");
    PPPetCareViewerVC *viewer = [[PPPetCareViewerVC alloc] initWithMedicine:medicine
                                                               mainKindName:mainKindName];
    [self pp_openPetCareViewer:viewer];
}

- (void)pp_presentVetDetails:(VetModel *)vet
{
    PPPetCareVetViewrVC *viewer = [[PPPetCareVetViewrVC alloc] initWithVet:vet
                                                              mainKindName:[self pp_mainKindNameForID:vet.petMainKindID]];
    [self pp_openPetCareViewer:viewer];
}

- (void)pp_openPetCareViewer:(UIViewController *)viewer
{
    if (!viewer) {
        return;
    }
    viewer.hidesBottomBarWhenPushed = YES;
    UINavigationController *nav = self.navigationController;
    if (nav) {
        if (!PPIOS26()) {
            UIView *dimView = [[UIView alloc] initWithFrame:self.view.bounds];
            dimView.backgroundColor = [UIColor.blackColor colorWithAlphaComponent:0.0];
            dimView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            dimView.tag = 8726;
            dimView.accessibilityLabel = @"pp.serviceViewerDim";
            [self.view addSubview:dimView];
            [UIView animateWithDuration:0.22
                                  delay:0.0
                                options:UIViewAnimationOptionCurveEaseOut
                             animations:^{
                dimView.backgroundColor = [UIColor.blackColor colorWithAlphaComponent:0.22];
            } completion:nil];
        }
        [nav pushViewController:viewer animated:YES];
        return;
    }

    PPNavigationController *wrapped = [[PPNavigationController alloc] initWithRootViewController:viewer];
    wrapped.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewController:wrapped animated:YES completion:nil];
}

- (void)pp_callVet:(VetModel *)vet
{
    NSString *rawPhone = vet.phone.length > 0 ? vet.phone : vet.whatsapp;
    if (rawPhone.length == 0) {
        return;
    }

    NSMutableString *clean = [NSMutableString string];
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:@"+0123456789"];
    for (NSUInteger idx = 0; idx < rawPhone.length; idx++) {
        unichar ch = [rawPhone characterAtIndex:idx];
        if ([allowed characterIsMember:ch]) {
            [clean appendFormat:@"%C", ch];
        }
    }
    if (clean.length == 0) {
        return;
    }

    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"telprompt:%@", clean]];
    if (!url) {
        return;
    }
    UIApplication *application = UIApplication.sharedApplication;
    if ([application canOpenURL:url]) {
        [application openURL:url options:@{} completionHandler:nil];
    }
}

- (NSString *)pp_mainKindNameForID:(NSInteger)kindID
{
    if (kindID <= 0) {
        return PPPetCareLocalized(@"pet_care_all_pets", @"All pets");
    }
    for (MainKindsModel *kind in self.mainKinds) {
        if (kind.ID == kindID) {
            return kind.KindName.length > 0 ? kind.KindName : kind.KindNameEn ?: kind.KindNameAr ?: @"";
        }
    }
    return PPPetCareLocalized(@"pet_care_all_pets", @"All pets");
}

@end
