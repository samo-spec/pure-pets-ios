#import "CustomCollectionViewCell.h"
@interface CustomCollectionViewCell()

@property (nonatomic, strong) UIView *playerView;
@property (nonatomic, strong) UILabel *textLabel;


@end
@implementation CustomCollectionViewCell

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        // Initialize views

        // Image View Setup
        _imageView = [[UIImageView alloc] init];
        _imageView.contentMode = UIViewContentModeScaleAspectFit; // Or whatever you like
        [self.contentView addSubview:_imageView];

        // Video Player Layer Setup (Initially Hidden)
        _playerView = [[UIView alloc]init];
        _playerLayer = [[AVPlayerLayer alloc] init];
        [_playerView.layer addSublayer:_playerLayer];
        [self.contentView addSubview:_playerView];

        _textLabel = [[UILabel alloc]init];
        _textLabel.textAlignment = NSTextAlignmentCenter;
        [self.contentView addSubview:_textLabel];

        _imageView.translatesAutoresizingMaskIntoConstraints = false;
        _playerView.translatesAutoresizingMaskIntoConstraints = false;
        _textLabel.translatesAutoresizingMaskIntoConstraints = false;


        [NSLayoutConstraint activateConstraints:@[
           [_imageView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
           [_imageView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
           [_imageView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
           [_imageView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],

           [_playerView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
           [_playerView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
           [_playerView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
           [_playerView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],

            [_textLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
            [_textLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
            [_textLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
            [_textLabel.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],


        ]];


        _imageView.hidden = true;
        _playerView.hidden = true;
        _textLabel.hidden = true;
    }
    return self;
}

/*
 @property (nonatomic, assign) NSInteger FileType;
 @property (nonatomic, strong) NSString *FileName;
 @property (nonatomic, strong) NSString *FileUrl;
 @property (nonatomic, strong) NSString *CardID;

 @property (nonatomic, strong) NSURL *FirImageUrl;

 */
-(void)configureWithData:(NSDictionary*)data{

    NSString* type = data[@"FileType"];
    if ([type integerValue] == 0) {
        NSString* imageUrl = data[@"FileUrl"];
        [_player pause];
        _player = nil;
        _imageView.hidden = false;
        _playerView.hidden = true;
        _textLabel.hidden = true;
        [self loadImageFromUrl:imageUrl];
    }else if([type integerValue] == 1){
        NSString* videoUrl = data[@"FileUrl"];
        _imageView.hidden = true;
        _playerView.hidden = false;
        _textLabel.hidden = true;
         [self loadVideoFromUrl:videoUrl];
    }
   


}


- (void)prepareForReuse {
    [super prepareForReuse];
    [_player pause];
   [self.playerLayer removeFromSuperlayer];
    self.playerLayer = nil;
   self.player = nil;
    self.imageView.image = nil;


}

- (void)layoutSubviews {
    [super layoutSubviews];
        _playerLayer.frame = _playerView.bounds;
}

- (void)loadImageFromUrl:(NSString *)urlString {
    NSURL *url = [NSURL URLWithString:urlString];
    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDownloadTask *task = [session downloadTaskWithURL:url completionHandler:^(NSURL * _Nullable location, NSURLResponse * _Nullable response, NSError * _Nullable error) {

         if (!error) {
             NSData *data = [NSData dataWithContentsOfURL:location];

             UIImage *image = [UIImage imageWithData:data];
             dispatch_async(dispatch_get_main_queue(), ^{
                 self.imageView.image = image;
             });
         } else {
             NSLog(@"Error loading image: %@", error);
         }
     }];
     [task resume];
}

- (void)loadVideoFromUrl:(NSString *)videoString{
    NSURL* videoUrl = [NSURL URLWithString:videoString];

    AVPlayerItem *playerItem = [AVPlayerItem playerItemWithURL:videoUrl];
    _player = [AVPlayer playerWithPlayerItem:playerItem];
    _playerLayer.player = _player;
     [_player play];


}

@end
