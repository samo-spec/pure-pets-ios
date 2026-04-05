//
//  PPAdSubmitCoordinator 2.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 15/01/2026.
//


#import "PPAdSubmitCoordinator.h"
#import "PetAdManager.h"
#import "PPImageUploadValidator.h"
 

@interface PPAdSubmitCoordinator ()
@property (nonatomic, strong) PetAd *ad;
@property (nonatomic, assign) PPAdSubmitMode mode;
@property (nonatomic, strong) NSArray<UIImage *> *images;
@end

@implementation PPAdSubmitCoordinator

- (instancetype)initWithAd:(PetAd *)ad
                      mode:(PPAdSubmitMode)mode
                    images:(NSArray<UIImage *> *)images
{
    if (self = [super init]) {
        _ad = ad;
        _mode = mode;
        _images = images ?: @[];
    }
    return self;
}

- (void)start
{
    if (self.onStart) self.onStart();

    // ── Client-side image validation before any upload ──
    if (self.images.count > 0) {
        NSInteger failedIndex = 0;
        PPImageValidationResult result =
            [PPImageUploadValidator validateImages:self.images
                                       failedIndex:&failedIndex];
        if (result != PPImageValidationResultValid) {
            NSString *message = [PPImageUploadValidator localizedMessageForResult:result];
            NSError *validationError =
                [NSError errorWithDomain:@"PPAdSubmitCoordinator"
                                    code:(NSInteger)result
                                userInfo:@{
                                    NSLocalizedDescriptionKey: message,
                                    @"failedImageIndex": @(failedIndex)
                                }];
            if (self.onFailure) self.onFailure(validationError);
            return;
        }
    }

    if (self.mode == PPAdSubmitModeCreate) {
        [self createFlow];
    } else {
        [self updateFlow];
    }
}

#pragma mark - CREATE

- (void)createFlow
{
    // 🔒 Firestore doc MUST exist first
    [[PetAdManager sharedManager] addPetAd:self.ad completion:^(NSError *error) {

        if (error) {
            if (self.onFailure) self.onFailure(error);
            return;
        }

        if (self.images.count == 0) {
            if (self.onSuccess) self.onSuccess(self.ad);
            return;
        }

        [self uploadImagesThenUpdate];
    }];
}

#pragma mark - UPDATE

- (void)updateFlow
{
    if (self.images.count == 0) {
        [[PetAdManager sharedManager] updatePetAd:self.ad completion:^(NSError *error) {
            error ? self.onFailure(error) : self.onSuccess(self.ad);
        }];
        return;
    }

    [self uploadImagesThenUpdate];
}

#pragma mark - SHARED IMAGE PIPELINE

- (void)uploadImagesThenUpdate
{
    [self uploadUIImages:self.images forAd:self.ad completion:^(PetAd * _Nullable updatedAd, NSError * _Nullable error) {
        
        if (error) {
            if (self.onFailure) self.onFailure(error);
            return;
        }

        [[PetAdManager sharedManager]
         updatePetAd:updatedAd
         completion:^(NSError *error)
         {
            error ? self.onFailure(error) : self.onSuccess(updatedAd);
         }];
     }];
}


#pragma mark - Upload Handling (Fixed)

- (void)uploadUIImages:(NSArray<UIImage *> *)images
                 forAd:(PetAd *)ad
            completion:(void (^)(PetAd *_Nullable updatedAd, NSError *_Nullable error))completion
{
    NSLog(@"🟢 [uploadUIImages] START | adID=%@ | images=%lu",
          ad.adID, (unsigned long)images.count);

    if (images.count == 0) {
        NSLog(@"⚠️ [uploadUIImages] No images, returning immediately");
        completion(ad, nil);
        return;
    }

    FIRStorage *storage = [FIRStorage storage];
    FIRStorageReference *rootRef = storage.reference;

    dispatch_group_t group = dispatch_group_create();
    NSMutableArray<PetImageItem *> *items =
    [NSMutableArray<PetImageItem *> arrayWithCapacity:images.count];

    for (NSInteger i = 0; i < images.count; i++) {
        [items addObject:[[PetImageItem alloc] init]];
    }

    for (NSInteger idx = 0; idx < images.count; idx++) {

        UIImage *img = images[idx];
        if (!img) {
            NSLog(@"❌ [uploadUIImages] Image at index %ld is nil", (long)idx);
            continue;
        }

        NSLog(@"⬆️ [uploadUIImages] Uploading image %ld/%lu",
              (long)(idx + 1), (unsigned long)images.count);

        dispatch_group_enter(group);

        NSData *data = UIImageJPEGRepresentation(img, 0.75);
        if (!data) {
            NSLog(@"❌ [uploadUIImages] Failed to encode image at index %ld", (long)idx);
            dispatch_group_leave(group);
            continue;
        }

        NSString *fileName =
        [NSString stringWithFormat:@"%@_%ld.jpg", ad.adID, (long)idx];

        FIRStorageReference *ref =
        [rootRef child:[NSString stringWithFormat:@"pet_ads/%@", fileName]];

        [ref putData:data metadata:nil completion:^(FIRStorageMetadata *meta, NSError *error) {

            if (error) {
                NSLog(@"❌ [uploadUIImages] Upload failed idx=%ld | %@",
                      (long)idx, error.localizedDescription);
                dispatch_group_leave(group);
                return;
            }

            NSLog(@"✅ [uploadUIImages] Upload success idx=%ld", (long)idx);

            [ref downloadURLWithCompletion:^(NSURL *url, NSError *error2) {

                if (!url) {
                    NSLog(@"❌ [uploadUIImages] URL fetch failed idx=%ld | %@",
                          (long)idx, error2.localizedDescription);
                    dispatch_group_leave(group);
                    return;
                }

                NSLog(@"🔗 [uploadUIImages] Got download URL idx=%ld", (long)idx);

                // 🔥 BlurHash generation happens HERE
                [PPBlurHashGenerator generateBlurHashFromImage:img
                                                     completion:^(NSString *hash) {

                    NSLog(@"🎨 [uploadUIImages] BlurHash generated idx=%ld | %@",
                          (long)idx, hash.length > 0 ? @"YES" : @"NO");

                    PetImageItem *item =
                    [PetImageItem itemWithURL:url.absoluteString
                                        width:img.size.width
                                       height:img.size.height
                                     blurHash:hash];

                    items[idx] = item;

                    NSLog(@"📦 [uploadUIImages] ImageItem ready idx=%ld", (long)idx);

                    dispatch_group_leave(group);
                }];
            }];
        }];
    }

    dispatch_group_notify(group, dispatch_get_main_queue(), ^{

        NSMutableArray<PetImageItem *> *finalItems = [NSMutableArray array];
        for (id obj in items) {
            if ([obj isKindOfClass:PetImageItem.class]) {
                [finalItems addObject:obj];
            }
        }

        NSLog(@"🏁 [uploadUIImages] FINISHED | validItems=%lu",
              (unsigned long)finalItems.count);

        // 🔑 SINGLE SOURCE OF TRUTH
       // self.finalImageItems = finalItems;
        ad.imageItems = finalItems;

        NSLog(@"🧠 [uploadUIImages] Assigned imageItems to adID=%@",
              ad.adID);

        // ✅ Upload finished — images are now on the model
        completion(ad, nil);
    });
}


@end
