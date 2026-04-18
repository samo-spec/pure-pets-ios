#import "RoundedImageViewWithShadow.h"

@implementation RoundedImageViewWithShadow {
    CAShapeLayer *_progressLayer;
}

#pragma mark - Initializers

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) [self setupView];
    return self;
}

- (instancetype)initWithImage:(UIImage *)image {
    // Auto-size frame to image
    CGRect frame = CGRectMake(0, 0, image.size.width, image.size.height);
    self = [super initWithFrame:frame];
    if (self) {
        [self setupView];
        _imageView.image = image;
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame image:(UIImage *)image {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupView];
        _imageView.image = image;
    }
    return self;
}

- (void)awakeFromNib {
    [super awakeFromNib];
    [self setupView];
}

#pragma mark - Setup

- (void)setupView {
    self.backgroundColor = UIColor.whiteColor;
    self.clipsToBounds = NO;
    self.layer.masksToBounds = NO;

    // Shadow
    [self pp_setShadowColor:UIColor.blackColor];
    self.layer.shadowOffset = CGSizeMake(0, 2);
    self.layer.shadowOpacity = 0.2;
    self.layer.shadowRadius = 8;

    // Rounded mask based on frame
    self.layer.cornerRadius = self.bounds.size.width / 2.0;

    // Main image
    _imageView = [[UIImageView alloc] initWithFrame:self.bounds];
    _imageView.contentMode = UIViewContentModeScaleAspectFill;
    _imageView.clipsToBounds = YES;
    _imageView.layer.cornerRadius = self.bounds.size.width / 2.0;
    _imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self addSubview:_imageView];

    // Circular progress ring
    _progressLayer = [CAShapeLayer layer];
    _progressLayer.fillColor = UIColor.clearColor.CGColor;
    _progressLayer.strokeColor = GM.appPrimaryColor.CGColor;
    _progressLayer.lineWidth = 3.0;
    _progressLayer.lineCap = kCALineCapRound;
    _progressLayer.strokeEnd = 0.0;
    [self.layer addSublayer:_progressLayer];
}

#pragma mark - Path

- (UIBezierPath *)circularPath {
    CGFloat radius = MIN(self.bounds.size.width, self.bounds.size.height) / 2.0 - (_progressLayer.lineWidth / 2.0);

    CGPoint center = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));

    return [UIBezierPath bezierPathWithArcCenter:center
                                          radius:radius
                                      startAngle:-M_PI_2
                                        endAngle:(3 * M_PI_2)
                                       clockwise:YES];
}

#pragma mark - Setters

- (void)setProgress:(CGFloat)progress {
    _progress = progress;
    _progressLayer.strokeEnd = progress;
}

#pragma mark - Layout

- (void)layoutSubviews {
    [super layoutSubviews];

    self.layer.cornerRadius = self.bounds.size.width / 2.0;
    _imageView.layer.cornerRadius = self.bounds.size.width / 2.0;

    _progressLayer.frame = self.bounds;
    _progressLayer.path = [self circularPath].CGPath;

    self.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.bounds
                                                        cornerRadius:self.layer.cornerRadius].CGPath;
}

#pragma mark - Expose image

- (UIImage *)image {
    return _imageView.image;
}

@end
