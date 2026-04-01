//

//  Pure Pets
//
//  Created by Mohammed Ahmed on 04/08/2024.
//

#import "FileModel.h"




@implementation FileModel

- (instancetype)initWithDic:(NSDictionary *)Dict {
    self = [super init];
    if (self) {
       // NSLog(@"initWithSnapshot %@",snapshot.data[@"ImageName"]);
        self.ID =  [Dict[@"ID"] integerValue];
        self.FileType =  [Dict[@"fileType"] integerValue];
        self.FileName = Dict[@"FileName"];
        self.FileUrl = Dict[@"FileUrl"];
       
        self.FirImageUrl = Dict[@"FileUrl"];
        self.CardID = Dict[@"CardID"];
        self.CoverName = Dict[@"CoverName"];
        NSString *CoverUrlStr = [NSString stringWithFormat:@"%@",Dict[@"CoverUrl"]];
        
        NSString *prefixToCheck = @"https://";
        NSLog(@"CoverUrlStr %@",CoverUrlStr);
        if (![CoverUrlStr hasPrefix:prefixToCheck] || [CoverUrlStr isEqualToString:@"no_value"]) {
            self.CoverUrl = @"https://CoverUrlStrCoverUrlStr.com";
        } else {
           NSLog(@"The image name does not start with thumb_, not loading image");
            self.CoverUrl = Dict[@"CoverUrl"];
            
        }
        
    
        
    }
    return self;
}




@end
