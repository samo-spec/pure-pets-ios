//
//  AppManager.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 14/12/2024.
//
#import <FirebaseFirestore/FirebaseFirestore.h>
 
 
#import <UserNotifications/UserNotifications.h>
@class TrashModel;
@class TTGSnackbar;
// REMOVE IT LATER
#import "ISO8601DateFormatter.h"

typedef NS_ENUM(NSInteger, AppStyle)
{
    AppStyleLight,
    AppStyleDark,
    AppStyleAuto
};

typedef NS_ENUM(NSInteger, DataLoadingResult) {
    DataLoadingResultSuccess = 1,
    DataLoadingResultFailure = 0,
};

NS_ASSUME_NONNULL_BEGIN


@protocol MainDataManagerDelegate <NSObject>
- (void)dataDidChange;
@end


@interface AppManager : NSObject



@property (assign, nonatomic) AppStyle appStyle;
 
// REMOVE IT LATER
-(NSString *)MsgStrFtromDate:(NSDate *)msgDate;
-(NSDate *)MsgDateFromStr:(NSString *)msgDateStr;

 + (AppManager *)sharedInstance;

@property (nonatomic, strong) IBOutlet TTGSnackbar *snakBar;
@property (nonatomic, strong) FIRFirestore *dF;


-(void)showSnakBar:(NSString *)message withColor:(UIColor *)color andDuration:(float)duration containerView:(UIView *)containerView;

// FIR Images
-(void)setFirImageToPath:(NSString *)folderName andImageName:(NSString *)imageName toImageView:(UIImageView *)imgView;

@property(strong, nonatomic) NSMutableDictionary *urlsArray;
- (void)setImageUrlToCache:(NSString *)imageName imageUrl:(NSURL *)imageUrl;
- (NSURL *)getImageUrlFromCache:(NSString *)imageName;

@property (strong, nonatomic) ISO8601DateFormatter *formatter;
// COLORS
@property (nonatomic, retain) UIColor *appColorDarker;
@property (nonatomic, retain) UIColor *appColorShiner;
@property (nonatomic, retain) UIColor *appColor;
@property (nonatomic, retain) UIColor *appTintColor;
@property (nonatomic, retain) UIColor *appBackgroudColor;
@property (nonatomic, retain) UIColor *appContinersColor;
@property (nonatomic, retain) UIColor *appColorGreen;
@property (nonatomic, retain) UIColor *appColorShadow;
@property  (strong, nonatomic) NSString *subKindForBuyerVC;
+ (void)showSnakBar:(NSString *)message withColor:(UIColor *)color andDuration:(float)duration containerView:(UIView *)containerView;
- (void)setBasicData;

//@property (strong, nonatomic) NSMutableArray<CardModel *> *UserCardsDocs;
// Cards Arrays


// USERS
@property (nonatomic, strong) NSMutableArray<UserModel *> *usersArray;
@property (nonatomic, strong, nullable) id<FIRListenerRegistration> usersListener;
/// Listener for the trGCol (trigger) collection — real-time card transfer triggers.
@property (nonatomic, strong, nullable) id<FIRListenerRegistration> triggerListener;

@property (strong, nonatomic) NSMutableDictionary<NSString *, NSDictionary *> *localUsers;
@property (nonatomic, strong) _Nullable id<FIRListenerRegistration> listenerRegistration;
@property (nonatomic, strong) _Nullable id<FIRListenerRegistration> onlineStatusListener;
//@property (nonatomic, strong) _Nullable id<FIRListenerRegistration> cardsListener;
- (void)loadUsersDocuments:(void (^)(DataLoadingResult result))completionHandler;
@property (strong, nonatomic) dispatch_queue_t queue;

//Get Sub Kinds Array From MainKinds By subKindsID


// TRANSFORS
-(NSString *)managerStringfromDate:(NSDate *)date;
-(NSString *)formatDateFromDate:(NSDate *)date;

-(UIFont *)fontSize:(float )size;
-(UIFont *)boldFontSize:(float )size;

// CHAT
// SET DESIGN
- (void)setCornerRadius:(CGFloat)radius withOpacity:(CGFloat)opacity shadowOffset:(CGFloat)offset shadowRadius:(CGFloat)sharowRadis onView:(UIView *)view color:(UIColor *)color;

- (UIViewController *)topViewController;

- (void)uploadAudioData:(NSData *)audioData
              completion:(void (^)(NSString *downloadURL, NSError *error))completion;
- (void)uploadMP3FromPath:(NSString *)filePath
               completion:(void (^)(NSString *downloadURL,NSString *fileName, NSError *error))completion;

- (void)setupAppConfiguration;
@end

NS_ASSUME_NONNULL_END
