//

//  Pure Pets
//
//  Created by Mohammed Ahmed on 04/08/2024.
//




NS_ASSUME_NONNULL_BEGIN

@interface FileModel : NSObject


@property (nonatomic, assign) NSInteger ID;
@property (nonatomic, assign) NSInteger FileType;
@property (nonatomic, strong) NSString *FileName;
@property (nonatomic, strong) NSString *FileUrl;
@property (nonatomic, strong) NSString *CardID;
@property (nonatomic, strong) NSString *CoverName;
@property (nonatomic, strong) NSString *CoverUrl;
@property (nonatomic, assign) float videoDuration;

@property (nonatomic, strong) NSURL *FirImageUrl;
@property (nonatomic,retain) UIImage *imageFile;
- (instancetype)initWithDic:(NSDictionary *)Dict;


@end

NS_ASSUME_NONNULL_END
