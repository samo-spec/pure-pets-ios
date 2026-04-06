//
//  GM.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 05/01/2025.
//
#import <Foundation/Foundation.h>
#import <CommonCrypto/CommonCrypto.h>  // Required for SHA-256 hashing
#import <Security/Security.h> // Required for Key management
#import "FTPopOverMenu.h"
#import "CountryCodeModel.h"
@import Firebase;
@import FirebaseCore;
@import FirebaseStorage;
#import "Watermark.h"

#import "ChatThreadModel.h"
@class CountryCodeModel;
@class ArchiveModel;
@class CityModel;

// PPShortNSLog.h
#ifdef DEBUG
  #define PPShortNSLog(label, token, keep) do {                           \
      NSString *__t = (token) ?: @"<nil>";                                 \
      NSUInteger __k = MIN((NSUInteger)(keep), __t.length);                \
      NSString *__out = (__t.length > __k) ?                               \
          [[__t substringToIndex:__k] stringByAppendingString:@"…"] : __t; \
      NSLog(@"%@: %@", (label), __out);                                    \
  } while (0)
#else
  #define PPShortNSLog(label, token, keep) do { } while (0)
#endif

static inline BOOL PPIsNull(id _Nullable obj) {
    return obj == (id)kCFNull || obj == nil;
}

extern NSString * _Nullable const kUserNameRow;
extern NSString * _Nullable const kMobileNoRow ;
extern NSString * _Nullable const kuserIDRow;
extern NSString * _Nullable const kuserImageRow;
extern NSString * _Nullable const kfirstNameRow;
extern NSString * _Nullable const kLastNameRow;
extern NSString * _Nullable const kUserEmailRow;
extern NSString * _Nullable const kUserAboutRow;
extern NSString * _Nullable const kcodeRow;

typedef void (^CompletionBlock)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error);
typedef void (^VCompletionBlock)(NSInteger haveFile, NSString * _Nullable vidName, NSString * _Nullable url);
typedef void (^MediaCompletionBlock)(NSMutableArray * _Nullable FilesDictArray);
typedef void (^ImageCompletionBlock)(UIImage * _Nullable image, NSError * _Nullable error);
//typedef void (^AccessToken)(NSString * _Nullable access_token);
typedef void (^image)(UIImage * _Nullable image);
typedef void (^complete)(NSInteger complete);

NS_ASSUME_NONNULL_BEGIN

@interface GM : NSObject
+ (void)pp_setImageURL:(NSString *)urlString
             imageView:(UIImageView *)imageView
           placeholder:(NSString *)placeholder;
//+ (void)clearUserDefaults;
+ (UIImage *)setWatermarkImage:(UIImage *)watermarkImage toImage:(UIImage *)originalImage;

+ (NSString *)getCurrentCountryFromCarrier;
+ (NSMutableArray<CountryCodeModel *> *)getMiddleEastCountriesForLanguage:(NSString *)languageCode;

+ (void)generateImageLink:(NSString *)imageName storagePath:(NSString *)storagePath completion:(void(^)(NSString * _Nullable downloadURL, NSError * _Nullable error))completion ;

+ (void)shareOnWhatsApp:(UIImage *)imageToShare textToShare:(NSString *)textToShare fromView:(UIView *)fromView andController:(UIViewController *)controller;

+ (UIEdgeInsets)getSafeAreaInsets ;
+ (void)compressVideoAtURL:(NSURL *)inputURL completion:(void (^)(NSURL *outputURL, NSError *error))completion;


+ (void)getVideoThumbnail:(NSURL *)videoURL toImageView:(UIImageView *)imageView;
+ (NSData *)compressImage:(UIImage *)image withQuality:(CGFloat)quality;
+ (UIImage *)resizeImage:(UIImage *)image withMaxDimension:(CGFloat)maxDimension;
+ (void)uploadImage:(UIImage *)image andName:(NSString *)name
     withCompletion:(void (^)(NSString *downloadURL, NSError *error))completion;
+ (void)setImageFromUrlString:(NSString *)urlString imageView:(UIImageView *)imageView phImage:(NSString * _Nullable)phImage;
+ (void)setImageFromUrlString:(NSString *)urlString imageView:(UIImageView *)imageView phImage:(NSString * _Nullable)phImage completion:(_Nullable ImageCompletionBlock)completion;;
+ (void)getImageFromUrlString:(NSString *)urlString phImage:(NSString * _Nullable)phImage completion:(_Nullable ImageCompletionBlock)completion;
+ (void)setImageFromFirebaseURLString:(NSString *)urlString
                            imageView:(UIImageView *)imageView
                              phImage:(NSString * _Nullable)phImage
                          showShimmer:(BOOL)showShimmer
                           completion:(_Nullable ImageCompletionBlock)completion;

// CARD IMAGES REFRENSE
+(FIRStorageReference *)CardsImagesRefrence;
+(NSString *)CardsImagesRefStr;
//+(FIRStorageReference *)UserImagesRefrence;
+ (void)setShadow:(UIView *)view sh_Color:(UIColor *)color cGSize:(CGSize)size  sh_Opacity:(float)Opacity radius:(float)radus;

+ (void)uploadMedia:(NSMutableArray *)MediaFiles CardID:(NSString *)CardID completion:(MediaCompletionBlock)completion;
+ (void)uploadVideo:(NSString *)videoName  videoArray:(NSArray *)videoArray completion:(VCompletionBlock)completion;

+ (void)sendRequestWithURLString:(NSString *)urlString
                       httpMethod:(NSString *)httpMethod
                      jsonBody:(NSDictionary *)jsonBody
                       headers:(NSDictionary *)headers
                  completion:(CompletionBlock)completion;



+ (NSString *)ageFromBirthday:(NSDate *)birthdate;
+ (void)shareToWhatsApp:(NSString *)textToShare sharingImage:(UIImage *)sharingImage inViewController:(UIViewController *)VC;
+ (void)uploadImageToStories:(UIImage *)image forUserID:(NSString *)userID completion:(void (^_Nullable)(NSURL * _Nullable url))completion;
+(NSMutableArray *)getSegmentedTitleForLanguage:(NSInteger)languageCode;
+(void)ConfigEmptyViewForCollection:(UICollectionView *)collectionView Title:(NSString *)title Subtitle:(NSString *)Subtitle imageName:(NSString *)imageName completion:(void (^)(NSInteger complete))completion;
+ (NSString *)getArchiveTitleByID:(NSString *)archiveID fromArchiveArray:(NSArray<ArchiveModel *> *)archiveArray;
+ (ArchiveModel *)findArchiveModelWithMasterID:(NSString *)masterID;;
 
+(NSString *)formatDateFromDate:(NSDate *)date;

+(NSString *)movedPlacerUrl;

+ (NSData *)compressImageToMaxSize:(UIImage *)image maxSizeKB:(NSInteger)maxSizeKB;

+ (void)videoDurationFromURL:(NSURL *)videoURL completion:(void (^)(NSString *durationString))completion;

+ (void)getVideoThumbnail:(NSURL *)url completion:(void (^)(UIImage * _Nullable image, NSError * _Nullable error))completion;

+(NSMutableArray *)getAdsSegmentedTitleForLanguage:(NSInteger)languageCode;
+(NSMutableArray *)getAdsAccessSegmentedTitleForLanguage:(NSInteger)languageCode;

+ (void)animateCell:(UITableViewCell *)cell;

+ (void)gardToView:(UIView *)theView colorOne:(UIColor *)colorOne colorTwo:(UIColor *)colorTwo colorThree:(UIColor *)colorThree rds:(float )rds;

+ (void)logoutFromConroller:(UIViewController *)VC;


+ (CGFloat)topPadding;
+ (CGFloat)bottomPadding;

+ (FTPopOverMenuConfiguration *)configMenu:(FTPopOverMenuConfiguration *)configuration;

+ (UIFont *)fontWithSize:(float)fontSize;
+ (UIFont *)MidFontWithSize:(float)fontSize;
+ (UIFont *)boldFontWithSize:(float)fontSize;
+ (NSString *)formattedDate:(NSDate *)date;
+ (void)setXForView:(UILabel *)view inSuperview:(UIView *)superview padding:(CGFloat)padding;

+ (void)playSoundWithName:(NSString *)name type:(NSString *)type;

+ (void)sendPromptToGemini:(NSString *)prompt
                completion:(void (^)(NSString *responseText, NSError *error))completion;

+ (NSTextAlignment)setAligment ;


+(NSString *)cleanID;

+ (UIColor *)appPrimaryColor;
+ (UIColor *)AppPrimaryColorShainer;
+ (UIColor *)AppPrimaryColorDarker;
+(UIColor *)AppForegroundColor;
+(UIColor *)backOffwhileColor;
+ (UIColor *)AppShadowColor;
+ (UIColor *)PrimaryTextColor;
+ (UIColor *)SecondaryTextColor;
+ (UIColor *)PlaceholderTextColor;
+ (UIColor *)AccentsColor;
+ (UIColor *)AppWhiteColor;

+ (void)showLanguageSetupAlertFromForFirstTime:(UIViewController *)viewController;
+ (void)showLanguageAlert:(UIViewController *)viewController;

+ (NSString *)safeString:(id)value;

+ (void)chatWith:(UserModel *)user FromController:(UIViewController *)controller;

+ (void)showMessagingWithChat:(ChatThreadModel *)chat FromController:(UIViewController *)controller;

 + (void)triggerHapticFeedback;

+ (UIColor *)randomLightColor;
+(UISemanticContentAttribute)setSemantic;
+ (CGFloat)navBarPadding;

// GM.h
+ (NSString *)formatPrice:(id)price;
+ (NSString *)formatPrice:(id)price currencyCode:(NSString * _Nullable)currencyCode;
+ (NSString *)formatPrice:(id)price
             currencyCode:(NSString * _Nullable)currencyCode
                freeLabel:(NSString * _Nullable)freeLabel;



+ (void)showDeleteConfirmationFrom:(UIViewController *)viewController
                             title:(NSString *)title
                           message:(NSString *)message
                        completion:(void (^)(BOOL confirmed))completion;


/// Show/Hide the activity Lottie overlay on a controller's view
+ (void)ActivityLoadingAnimationView:(BOOL)show onController:(UIViewController *)vc;

/// (Optional) Show/Hide on any container view
+ (void)ActivityLoadingAnimationView:(BOOL)show onView:(UIView *)view;


+ (void)showAlertWithTitle:(NSString *)title
                  message:(NSString *)message
                   imageName:(NSString *)imageName
          inViewController:(UIViewController *)viewController;

 
 + (void)fetchDownloadURLForPath:(NSString *)path
                     imageName:(NSString *)imageName
                     completion:(void (^)(NSURL * _Nullable url, NSError * _Nullable error))completion;

+ (void)PPSDImageWithURL:(NSString *)urlString
                    imageView:(UIImageView *)imageView
                      phImage:(NSString * _Nullable)phImage
              completion:(ImageCompletionBlock)completion;







+ (void)fetchImageFromURLString:(NSString *)urlString
                     completion:(ImageCompletionBlock)completion;
+ (void)fetchImageFromURLString:(NSString *)urlString
                    placeholder:(NSString * _Nullable)placeholderName
                     completion:(ImageCompletionBlock)completion;
+ (void)downloadImageFromURL:(NSURL *)url
                 placeholder:(NSString * _Nullable)placeholderName
                  completion:(ImageCompletionBlock)completion;
+ (UIImage *)cachedImageForURL:(NSURL *)url;

+ (void)clearImagesDiskCache ;
@end

NS_ASSUME_NONNULL_END



















 
