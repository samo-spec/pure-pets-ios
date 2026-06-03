//
//  PPImageCollection.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 03/12/2025.
//


#import <UIKit/UIKit.h>
#import <Photos/Photos.h>
#import "PPImageManager.h"
#import "PPImageCollection.h"
#import "QBImagePickerController.h"

#import <Pure_Pets-Swift.h>
@class PPEditorBridge;


NS_ASSUME_NONNULL_BEGIN

@class PPImageCollection;
@class PPMediaUploadResult;

typedef void (^PPImageCollectionMediaUploadCompletion)(PPMediaUploadResult * _Nullable result,
                                                       NSError * _Nullable error);
typedef void (^PPImageCollectionSingleMediaCompletion)(NSDictionary * _Nullable metadata,
                                                       NSError * _Nullable error);

@interface PPMediaUploadResult : NSObject
@property (nonatomic, copy, readonly) NSArray<NSString *> *imageURLs;
@property (nonatomic, copy, readonly) NSArray<NSDictionary *> *imageMetadata;
@property (nonatomic, copy, readonly) NSArray<NSString *> *videoURLs;
@property (nonatomic, copy, readonly) NSArray<NSDictionary *> *videoMetadata;
@property (nonatomic, copy, readonly) NSArray<NSDictionary *> *mixedMetadata;
@property (nonatomic, assign, readonly) BOOL hasVideos;
@property (nonatomic, assign, readonly) BOOL hasImages;
- (instancetype)init NS_UNAVAILABLE;
@end

@protocol PPImageCollectionDelegate <NSObject>
@optional
- (void)imageCollection:(PPImageCollection *)collection didUpdateImages:(NSArray<UIImage *> *)images;
- (void)imageCollection:(PPImageCollection *)collection didSelectImage:(UIImage *)selectedImage  AtIndex:(NSInteger)index;
- (void)imageCollectionDidRequestAddImage:(PPImageCollection *)collection;
@end

@interface PPImageCollection : UIView <UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, QBImagePickerControllerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIDocumentPickerDelegate>

@property (nonatomic, weak) id<PPImageCollectionDelegate> delegate;
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) NSMutableArray<UIImage *> *mediaOutputArray;
@property (nonatomic, strong) PPImageManager *imageManager;
@property (nonatomic, strong) PPEditorBridge *editorBridge;

// Configuration
@property (nonatomic, assign) NSInteger maxImageCount;
@property (nonatomic, assign) BOOL useArabic;
@property (nonatomic, assign) BOOL allowsEditing;
@property (nonatomic, assign) BOOL allowsReordering;
@property (nonatomic, assign) BOOL allowsVideoSelection;
@property (nonatomic, strong) NSString *titleText;
@property (nonatomic, assign) UIEdgeInsets headerContentInsets;

// State
@property (nonatomic, assign) NSInteger selectedForEdit;
@property (nonatomic, strong) NSRecursiveLock *arrayLock;

// Initialization
- (instancetype)initWithFrame:(CGRect)frame maxImageCount:(NSInteger)maxCount useArabic:(BOOL)useArabic;
- (void)presentEditorForImageAtIndex:(NSInteger)index fromViewController:(UIViewController *)viewController ;
- (void)presentPickerFromViewController:(UIViewController *)viewController;
// Image Management
- (void)addImage:(UIImage *)image;
- (void)addImages:(NSArray<UIImage *> *)images;
- (void)addVideoWithURL:(NSURL *)videoURL thumbnail:(UIImage * _Nullable)thumbnail;
- (void)removeImageAtIndex:(NSInteger)index;
- (void)replaceImageAtIndex:(NSInteger)index withImage:(UIImage *)image;
- (void)clearAllImages;
- (NSArray<UIImage *> *)allImages;
- (NSArray<UIImage *> *)allPhotoImages;
- (NSArray<NSURL *> *)allVideoURLs;
- (BOOL)hasSelectedVideos;
- (NSArray<NSDictionary *> *)selectedImageMetadata;
- (NSArray<NSDictionary *> *)selectedVideoMetadata;
- (NSArray<NSDictionary *> *)selectedMixedMediaMetadata;
- (NSInteger)imageCount;

// Reusable Firebase media upload. When PPReusableVideoMediaEnabled() is OFF,
// this returns image-only metadata and never uploads video media.
- (void)uploadSelectedMediaWithStorageFolder:(NSString *)storageFolder
                                     ownerID:(NSString *)ownerID
                                   contextID:(NSString * _Nullable)contextID
                                  completion:(PPImageCollectionMediaUploadCompletion)completion;

// App media storage helpers:
// uploadMedia(entityType, entityId, file, mediaType)
// deleteMedia(storagePath)
// replaceMedia(oldStoragePath, newFile) returns new metadata plus old paths;
// commit Firestore first, then delete returned old paths.
// deleteEntityMedia(entityType, entityId)
+ (void)uploadMediaWithEntityType:(NSString *)entityType
                          entityID:(NSString *)entityID
                              file:(id)file
                         mediaType:(NSString *)mediaType
                           ownerID:(NSString * _Nullable)ownerID
                         completion:(PPImageCollectionSingleMediaCompletion)completion;
+ (void)deleteMediaAtStoragePath:(NSString *)storagePath
                       completion:(void(^ _Nullable)(NSError * _Nullable error))completion;
+ (void)replaceMediaAtOldStoragePath:(NSString *)oldStoragePath
                           entityType:(NSString *)entityType
                             entityID:(NSString *)entityID
                                 file:(id)file
                            mediaType:(NSString *)mediaType
                              ownerID:(NSString * _Nullable)ownerID
                            completion:(PPImageCollectionSingleMediaCompletion)completion;
+ (void)deleteEntityMediaWithEntityType:(NSString *)entityType
                               entityID:(NSString *)entityID
                             completion:(void(^ _Nullable)(NSError * _Nullable error))completion;

// UI Management
- (void)reloadCollectionView;
- (void)setTitle:(NSString *)title icon:(UIImage * _Nullable)icon;

// Preloading
- (void)preloadImagesFromURLs:(NSArray<NSString *> *)urls completion:(void(^)(void))completion;
- (void)preloadMediaMetadata:(NSArray<NSDictionary *> *)metadata completion:(void(^)(void))completion;

@end

NS_ASSUME_NONNULL_END
