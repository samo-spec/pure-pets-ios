//

//  Pure Pets
//
//  Created by Mohammed Ahmed on 04/08/2024.
//

#import "ImageModel.h"


@implementation ImageModel

- (instancetype)initWithSnapshot:(FIRDocumentSnapshot *)snapshot {
    self = [super init];
    if (self) {
       // NSLog(@"initWithSnapshot %@",snapshot.data[@"ImageName"]);
        self.ImageID = snapshot.data[@"ID"];
        self.ImageName = snapshot.data[@"ImageName"];
       
        self.fileType = [snapshot.data[@"fileType"] integerValue];
        if( self.fileType == FileTypeImage){
            [self setUrlLocal:snapshot.data[@"ImageName"]];
        }else if (self.fileType == FileTypeVideo){
            self.FirImageUrl =  [NSURL  URLWithString:[NSString stringWithFormat:@"%@", self.FirImageUrl]];
        }
    }
    return self;
}


-(void)setUrlLocalVideo:(NSString *)imageName{

    if([[AppManager sharedInstance] getImageUrlFromCache:self.ImageName] == nil)
    {
        FIRStorage *storage = [FIRStorage storage];
        FIRStorageReference *storageRef = [storage reference];
        // Create a reference to the file you want to download
        NSString *str = [NSString stringWithFormat:@"%@/%@",[GM CardsImagesRefStr],self.ImageName];
        FIRStorageReference *starsRef = [storageRef child:str];
        
        
        // Fetch the download URL
        [starsRef downloadURLWithCompletion:^(NSURL *URL, NSError *error){
            if (error != nil) {
                // Handle any errors
            } else {
                [[AppManager sharedInstance] setImageUrlToCache:self.ImageName imageUrl:URL];
                //NSLog(@"FirImageUrl ------------------------->> Server %@",URL);
                self.FirImageUrl =  URL;
            }
        }];
    }
    else
    {
       
        self.FirImageUrl = [[AppManager sharedInstance] getImageUrlFromCache:self.ImageName];
        //NSLog(@"FirImageUrl ------------------------->>  Cache %@",self.FirImageUrl);
    }
    
}

-(void)setUrlLocal:(NSString *)imageName{
    
    
    if([[AppManager sharedInstance] getImageUrlFromCache:self.ImageName] == nil)
    {
        FIRStorage *storage = [FIRStorage storage];
        FIRStorageReference *storageRef = [storage reference];
        // Create a reference to the file you want to download
        NSString *str = [NSString stringWithFormat:@"%@/%@",[GM CardsImagesRefStr],self.ImageName];
        FIRStorageReference *starsRef = [storageRef child:str];
        
        
        // Fetch the download URL
        [starsRef downloadURLWithCompletion:^(NSURL *URL, NSError *error){
            if (error != nil) {
                // Handle any errors
            } else {
                [[AppManager sharedInstance] setImageUrlToCache:self.ImageName imageUrl:URL];
                //NSLog(@"FirImageUrl ------------------------->> Server %@",URL);
                self.FirImageUrl =  URL;
            }
        }];
    }
    else
    {
       
        self.FirImageUrl = [[AppManager sharedInstance] getImageUrlFromCache:self.ImageName];
        //NSLog(@"FirImageUrl ------------------------->>  Cache %@",self.FirImageUrl);
    }
    
}

-(NSString *)ImageUrl{
    return [NSString stringWithFormat:@"%@",self.FirImageUrl.absoluteString];
}
- (nonnull NSString *)getImagesUrls:(nonnull NSString *)ImageName {
    return @"";
}

@end
