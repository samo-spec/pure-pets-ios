//
//  ImageCell.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 08/01/2025.
//

//ImageCell.m
#import "ImageCell.h"
@interface ImageCell()
@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) NSURLSessionDataTask *imageTask;
@property (nonatomic, copy) NSString *currentURLString;

@end
@implementation ImageCell

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupImageView];
    }
    return self;
}

-(void)setupImageView
{
    // Setup the image view
    self.imageView = [[UIImageView alloc] initWithFrame:self.contentView.bounds];
    self.imageView.contentMode = UIViewContentModeScaleAspectFit;
    [self.contentView addSubview:self.imageView];
}

-(void)loadImage:(NSURL *)url
{
    [self.imageTask cancel];
    self.currentURLString = url.absoluteString ?: @"";
    self.imageView.image = nil;

    NSURLSession *session = [NSURLSession sharedSession];
    __weak typeof(self) weakSelf = self;
    self.imageTask = [session dataTaskWithURL:url completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || error || data.length == 0) {
            return;
        }

        UIImage *image = [UIImage imageWithData:data];
        if (!image) {
            return;
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            if (![strongSelf.currentURLString isEqualToString:url.absoluteString ?: @""]) {
                return;
            }
            strongSelf.imageView.image = image;
        });
    }];
    
    [self.imageTask resume];
}

-(void)prepareForReuse
{
    [super prepareForReuse];
    [self.imageTask cancel];
    self.imageTask = nil;
    self.currentURLString = nil;
    self.imageView.image = nil;
}
@end 
