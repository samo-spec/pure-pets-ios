//

//  Pure Pets
//
//  Created by Mohammed Ahmed on 04/08/2024.
//


@import FirebaseFirestore;

typedef NS_ENUM(NSInteger, FileType)
{
    FileTypeImage = 0,
    FileTypeVideo = 1
};


NS_ASSUME_NONNULL_BEGIN

@interface ImageModel : NSObject
@property (nonatomic, strong) NSString *ImageID;
@property (nonatomic, strong) NSString *ImageName;
@property (nonatomic, strong) NSString *ImageUrl;
@property (nonatomic, strong) NSURL *FirImageUrl;
@property (nonatomic, assign) FileType fileType;
-(NSString *)getImagesUrls:(NSString *)ImageName;
//FIRCollectionReference *ImagesRef;
- (instancetype)initWithSnapshot:(FIRDocumentSnapshot *)snapshot;


@end

NS_ASSUME_NONNULL_END

