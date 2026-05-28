//
//  PPNovaReviewMessageCell.m
//  Pure Pets
//

#import "PPNovaReviewMessageCell.h"
#import "AppManager.h"

@interface PPNovaReviewMessageCell ()

@property (nonatomic, strong) UILabel *fallbackLabel;

@end

@implementation PPNovaReviewMessageCell

+ (NSString *)reuseIdentifier {
    return @"PPNovaReviewMessageCell";
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        [self setupUI];
    }
    return self;
}

- (void)setupUI {
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    self.backgroundColor = [UIColor clearColor];
    
    self.fallbackLabel = [[UILabel alloc] init];
    self.fallbackLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.fallbackLabel.text = @"";
    self.fallbackLabel.hidden = YES;
    self.fallbackLabel.textColor = [UIColor systemGrayColor];
    self.fallbackLabel.font = [UIFont italicSystemFontOfSize:14.0];
    self.fallbackLabel.textAlignment = NSTextAlignmentCenter;
    
    [self.contentView addSubview:self.fallbackLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.fallbackLabel.centerXAnchor constraintEqualToAnchor:self.contentView.centerXAnchor],
        [self.fallbackLabel.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        [self.fallbackLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:16],
        [self.fallbackLabel.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-16]
    ]];
}

- (void)configureWithMessage:(ChatMessageModel *)messageModel maxWidth:(CGFloat)maxWidth {
    // Stub implementation for rendering a review
}

@end
